"""Provision one bounded AWS VM; application deployment remains provider independent."""

from __future__ import annotations

import base64
import fcntl
import hashlib
import ipaddress
import json
import math
import os
import subprocess
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any
from urllib.request import urlopen

from host import Cloud, operator_root, private_write, read_json


def digest(target: dict[str, Any]) -> str:
    return hashlib.sha256(Path(target["_source"]).read_bytes()).hexdigest()


@contextmanager
def locked(target: dict[str, Any]):
    root = operator_root(target)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (root / "operation.lock").open("a") as lock:
        os.fchmod(lock.fileno(), 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield root


def provision_spec(target: dict[str, Any]) -> dict[str, Any]:
    spec = target["infrastructure"]
    expected = {"kind", "instance_type", "disk_gb", "ami_parameter", "vpc_id", "subnet_id", "monthly_limit_usd"}
    if set(spec) != expected or spec["kind"] != "aws":
        raise ValueError("This target needs an exact AWS VM specification")
    if (
        type(spec["disk_gb"]) is not int
        or spec["disk_gb"] < 30
        or type(spec["monthly_limit_usd"]) not in {int, float}
        or not math.isfinite(spec["monthly_limit_usd"])
        or spec["monthly_limit_usd"] <= 0
    ):
        raise ValueError("VM disk size or monthly planning limit is outside the bounded host policy")
    return spec


def price_rate(cloud: Cloud, service: str, attributes: dict[str, str], unit: str) -> float:
    filters = [{"Type": "TERM_MATCH", "Field": field, "Value": value} for field, value in attributes.items()]
    prices = cloud.aws("pricing", "get-products", "--service-code", service, "--filters", json.dumps(filters))[
        "PriceList"
    ]
    rates = {
        float(dimension["pricePerUnit"]["USD"])
        for product in prices
        for term in json.loads(product)["terms"]["OnDemand"].values()
        for dimension in term["priceDimensions"].values()
        if dimension["unit"] == unit
    }
    if len(rates) != 1:
        raise ValueError(f"Could not resolve one {service} {unit} price for the selected region")
    return rates.pop()


def plan_host(target: dict[str, Any]) -> None:
    spec = provision_spec(target)
    cloud = Cloud(target)
    with locked(target) as root:
        key_file = root / "id_ed25519"
        if not key_file.exists():
            subprocess.run(
                ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", target["id"], "-f", str(key_file)], check=True
            )
            key_file.chmod(0o600)
        image_id = cloud.aws("ssm", "get-parameter", "--name", spec["ami_parameter"])["Parameter"]["Value"]
        image = cloud.aws("ec2", "describe-images", "--image-ids", image_id)["Images"][0]
        if image["OwnerId"] != "099720109477" or image["Architecture"] != "x86_64":
            raise ValueError("Selected AMI is not the expected Canonical amd64 image")
        subnet = cloud.aws("ec2", "describe-subnets", "--subnet-ids", spec["subnet_id"])["Subnets"][0]
        if subnet["VpcId"] != spec["vpc_id"] or not subnet["MapPublicIpOnLaunch"]:
            raise ValueError("Selected subnet is outside the target VPC or is not public")
        size = cloud.aws("ec2", "describe-instance-types", "--instance-types", spec["instance_type"])["InstanceTypes"][
            0
        ]
        if image["Architecture"] not in size["ProcessorInfo"]["SupportedArchitectures"]:
            raise ValueError("Selected VM and image architectures differ")
        filters = [
            {"Type": "TERM_MATCH", "Field": field, "Value": value}
            for field, value in {
                "instanceType": spec["instance_type"],
                "regionCode": target["connection"]["region"],
                "operatingSystem": "Linux",
                "tenancy": "Shared",
                "preInstalledSw": "NA",
                "capacitystatus": "Used",
            }.items()
        ]
        prices = cloud.aws("pricing", "get-products", "--service-code", "AmazonEC2", "--filters", json.dumps(filters))[
            "PriceList"
        ]
        rates = {
            float(dimension["pricePerUnit"]["USD"])
            for product in prices
            for term in json.loads(product)["terms"]["OnDemand"].values()
            for dimension in term["priceDimensions"].values()
            if dimension["unit"] == "Hrs"
        }
        if len(rates) != 1:
            raise ValueError("Could not resolve one on-demand Linux instance rate")
        hourly = rates.pop()
        region = target["connection"]["region"]
        storage = price_rate(
            cloud, "AmazonEC2", {"regionCode": region, "productFamily": "Storage", "volumeApiName": "gp3"}, "GB-Mo"
        )
        address_rate = price_rate(cloud, "AmazonVPC", {"regionCode": region, "group": "VPCPublicIPv4Address"}, "Hrs")
        estimate = round(hourly * 730 + spec["disk_gb"] * storage + 730 * address_rate, 2)
        if estimate > spec["monthly_limit_usd"]:
            raise ValueError("Selected VM exceeds the target's monthly planning allowance")
        with urlopen("https://checkip.amazonaws.com", timeout=15) as response:
            address = str(ipaddress.IPv4Address(response.read().decode().strip()))
        plan = {
            "version": 1,
            "target_id": target["id"],
            "target_sha256": digest(target),
            "account_id": target["connection"]["account_id"],
            "image_id": image_id,
            "root_device": image["RootDeviceName"],
            "zone": subnet["AvailabilityZone"],
            "operator_cidr": address + "/32",
            "public_key": key_file.with_suffix(".pub").read_text().strip(),
            "key_file": str(key_file),
            "hourly_vm_usd": hourly,
            "monthly_gp3_gb_usd": storage,
            "hourly_ipv4_usd": address_rate,
            "estimated_monthly_usd": estimate,
            "client_token": uuid.uuid4().hex,
        }
        existing = root / "provision-progress.json"
        if existing.exists():
            raise ValueError("Provisioning already started; resume cloud-create with its existing plan")
        private_write(root / "provision-plan.json", json.dumps(plan, indent=2) + "\n")
        print(json.dumps(plan, indent=2))


def save_progress(root: Path, progress: dict[str, Any]) -> None:
    private_write(root / "provision-progress.json", json.dumps(progress, indent=2) + "\n")


def owned(items: list[dict[str, Any]], target_id: str) -> dict[str, Any] | None:
    if not items:
        return None
    if len(items) != 1:
        raise ValueError("Expected at most one resource for this target")
    tags = {tag["Key"]: tag["Value"] for tag in items[0].get("Tags", [])}
    if tags.get("CornerstoneTarget") != target_id:
        raise ValueError("Refusing to adopt an unowned resource")
    return items[0]


def verify_host_key(cloud: Cloud, target: dict[str, Any], progress: dict[str, Any], root: Path) -> Path:
    destination = root / "known_hosts"
    if destination.exists():
        return destination
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        console = cloud.aws("ec2", "get-console-output", "--instance-id", progress["instance_id"], "--latest")
        output = console.get("Output", "")
        if "SSH HOST KEY" not in output:
            try:
                output = base64.b64decode(output).decode(errors="replace")
            except (ValueError, UnicodeError):
                output = ""
        scan = subprocess.run(
            ["ssh-keyscan", "-T", "8", "-t", "ed25519", progress["hostname"]], capture_output=True, text=True
        )
        lines = [line for line in scan.stdout.splitlines() if not line.startswith("#")]
        if len(lines) == 1:
            candidate = root / "host-key-candidate"
            private_write(candidate, lines[0] + "\n")
            fingerprint = subprocess.check_output(["ssh-keygen", "-lf", str(candidate)], text=True).split()[1]
            if fingerprint in output:
                fields = lines[0].split()
                private_write(destination, f"{progress['instance_id']} {fields[1]} {fields[2]}\n")
                candidate.unlink()
                return destination
        time.sleep(10)
    raise ValueError("Could not verify the SSH host key against authenticated EC2 console output")


def create_host(target: dict[str, Any]) -> None:
    spec = provision_spec(target)
    cloud = Cloud(target)
    with locked(target) as root:
        plan = read_json(root / "provision-plan.json")
        if plan["target_sha256"] != digest(target) or plan["account_id"] != target["connection"]["account_id"]:
            raise ValueError("Target changed after planning")
        with urlopen("https://checkip.amazonaws.com", timeout=15) as response:
            operator_cidr = str(ipaddress.IPv4Address(response.read().decode().strip())) + "/32"
        if operator_cidr != plan["operator_cidr"]:
            raise ValueError("Operator address changed after planning")
        progress_file = root / "provision-progress.json"
        progress = (
            read_json(progress_file)
            if progress_file.exists()
            else {"target_id": target["id"], "provider": target["provider"], "target_sha256": digest(target)}
        )
        if progress["target_sha256"] != digest(target):
            raise ValueError("Existing resource state belongs to another target revision")
        save_progress(root, progress)
        tags = [{"Key": "CornerstoneTarget", "Value": target["id"]}, {"Key": "Name", "Value": target["id"]}]
        name = target["id"]
        if "key_name" not in progress:
            keys = cloud.aws(
                "ec2", "describe-key-pairs", "--filters", f"Name=key-name,Values={name}", "--include-public-key"
            )["KeyPairs"]
            key = owned(keys, name)
            if key is None:
                key = cloud.aws(
                    "ec2",
                    "import-key-pair",
                    "--key-name",
                    name,
                    "--public-key-material",
                    "fileb://" + str(Path(plan["key_file"]).with_suffix(".pub")),
                    "--tag-specifications",
                    json.dumps([{"ResourceType": "key-pair", "Tags": tags}]),
                )
            elif key.get("PublicKey", "").split()[:2] != plan["public_key"].split()[:2]:
                raise ValueError("Existing target key pair has different key material")
            progress["key_name"] = name
            save_progress(root, progress)
        if "security_group_id" not in progress:
            groups = cloud.aws(
                "ec2",
                "describe-security-groups",
                "--filters",
                f"Name=group-name,Values={name}",
                f"Name=vpc-id,Values={spec['vpc_id']}",
            )["SecurityGroups"]
            group = owned(groups, name)
            if group is None:
                group = cloud.aws(
                    "ec2",
                    "create-security-group",
                    "--group-name",
                    name,
                    "--description",
                    "Cornerstone HTTPS and operator SSH",
                    "--vpc-id",
                    spec["vpc_id"],
                    "--tag-specifications",
                    json.dumps([{"ResourceType": "security-group", "Tags": tags}]),
                )
            progress["security_group_id"] = group["GroupId"]
            save_progress(root, progress)
        permissions = [
            {"IpProtocol": "tcp", "FromPort": port, "ToPort": port, "IpRanges": [{"CidrIp": cidr}]}
            for port, cidr in [(22, plan["operator_cidr"]), (80, "0.0.0.0/0"), (443, "0.0.0.0/0")]
        ]
        current = cloud.aws("ec2", "describe-security-groups", "--group-ids", progress["security_group_id"])[
            "SecurityGroups"
        ][0]
        if not current["IpPermissions"]:
            cloud.aws(
                "ec2",
                "authorize-security-group-ingress",
                "--group-id",
                progress["security_group_id"],
                "--ip-permissions",
                json.dumps(permissions),
            )
        else:
            actual = {
                (p.get("IpProtocol"), p.get("FromPort"), p.get("ToPort"), ip["CidrIp"])
                for p in current["IpPermissions"]
                for ip in p.get("IpRanges", [])
            }
            expected = {
                ("tcp", port, port, cidr)
                for port, cidr in [(22, plan["operator_cidr"]), (80, "0.0.0.0/0"), (443, "0.0.0.0/0")]
            }
            if actual != expected or any(
                p.get("Ipv6Ranges") or p.get("UserIdGroupPairs") or p.get("PrefixListIds")
                for p in current["IpPermissions"]
            ):
                raise ValueError("Target security group has unexpected ingress")
        if "allocation_id" not in progress:
            addresses = cloud.aws(
                "ec2", "describe-addresses", "--filters", f"Name=tag:CornerstoneTarget,Values={name}"
            )["Addresses"]
            address = owned(addresses, name)
            if address is None:
                address = cloud.aws(
                    "ec2",
                    "allocate-address",
                    "--domain",
                    "vpc",
                    "--tag-specifications",
                    json.dumps([{"ResourceType": "elastic-ip", "Tags": tags}]),
                )
            progress["allocation_id"] = address["AllocationId"]
            progress["hostname"] = address["PublicIp"]
            save_progress(root, progress)
        if "instance_id" not in progress:
            user_data = """#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io docker-compose-v2 ca-certificates curl
systemctl enable --now docker
"""
            request = {
                "ImageId": plan["image_id"],
                "InstanceType": spec["instance_type"],
                "MinCount": 1,
                "MaxCount": 1,
                "ClientToken": plan["client_token"],
                "KeyName": progress["key_name"],
                "NetworkInterfaces": [
                    {
                        "DeviceIndex": 0,
                        "SubnetId": spec["subnet_id"],
                        "Groups": [progress["security_group_id"]],
                        "AssociatePublicIpAddress": True,
                    }
                ],
                "BlockDeviceMappings": [
                    {
                        "DeviceName": plan["root_device"],
                        "Ebs": {
                            "VolumeSize": spec["disk_gb"],
                            "VolumeType": "gp3",
                            "Encrypted": True,
                            "DeleteOnTermination": False,
                        },
                    }
                ],
                "MetadataOptions": {"HttpTokens": "required", "HttpPutResponseHopLimit": 1},
                "DisableApiTermination": True,
                "UserData": base64.b64encode(user_data.encode()).decode(),
                "TagSpecifications": [{"ResourceType": kind, "Tags": tags} for kind in ["instance", "volume"]],
            }
            result = cloud.aws("ec2", "run-instances", "--cli-input-json", json.dumps(request))
            progress["instance_id"] = result["Instances"][0]["InstanceId"]
            save_progress(root, progress)
            print("Created", progress["instance_id"], flush=True)
        cloud.aws("ec2", "wait", "instance-running", "--instance-ids", progress["instance_id"])
        cloud.aws(
            "ec2",
            "associate-address",
            "--instance-id",
            progress["instance_id"],
            "--allocation-id",
            progress["allocation_id"],
            "--no-allow-reassociation",
        )
        known_hosts = verify_host_key(cloud, target, progress, root)
        progress.update(
            {
                "key_file": plan["key_file"],
                "known_hosts_file": str(known_hosts),
                "estimated_monthly_usd": plan["estimated_monthly_usd"],
            }
        )
        private_write(root / "host.json", json.dumps(progress, indent=2) + "\n")
        print(json.dumps(progress, indent=2))
