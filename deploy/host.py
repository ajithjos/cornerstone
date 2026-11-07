#!/usr/bin/env python3
"""Cloud identity, target configuration and transport for the shared VM deployer."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PROVIDERS = {"aws", "azure", "gcp", "ssh"}
SECRET_FILES = {"runtime_env": "runtime-env.json"}


def string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value or value.startswith("-") or any(c in value for c in "\n\r\0"):
        raise ValueError(f"{label} must be a nonempty single-line string")
    return value


def absolute(value: Any, label: str) -> Path:
    path = Path(string(value, label))
    if not path.is_absolute() or path.is_symlink() or path == Path("/"):
        raise ValueError(f"{label} must be an absolute non-symlink path")
    return path


def read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"Expected an object in {path}")
    return data


def private_write(path: Path, data: str) -> None:
    if path.is_symlink():
        raise ValueError(f"Refusing symlink output: {path}")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".new")
    with temporary.open("x") as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(data)
    temporary.replace(path)


def private_file(path: Path) -> Path:
    if not path.is_file() or path.is_symlink() or path.stat().st_mode & 0o077:
        raise ValueError(f"Private input must be a regular owner-only file: {path}")
    return path


def load_target(selected: str = "", provider: str | None = None) -> dict[str, Any]:
    provider = provider or os.environ.get("CLOUD", "aws")
    selected = selected or os.environ.get("CLOUD_TARGET", "") or f"deploy/config/environments/prod.{provider}.json"
    source = Path(selected)
    if not source.is_absolute():
        source = ROOT / source
    source = source.resolve()
    target = read_json(source)
    keys = {"version", "id", "provider", "connection", "transport", "application", "secrets", "infrastructure"}
    if set(target) != keys or type(target["version"]) is not int or target["version"] != 1:
        raise ValueError("Expected the exact version-1 deployment target schema")
    if target["provider"] not in PROVIDERS or target["provider"] != provider:
        raise ValueError("CLOUD and CLOUD_TARGET provider must match")
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,62}", string(target["id"], "id")):
        raise ValueError("Invalid target id")
    connection = target["connection"]
    expected = {
        "aws": {"provider", "profile", "account_id", "region"},
        "azure": {"provider", "profile", "account", "subscription_id", "tenant_id"},
        "gcp": {"provider", "profile", "account", "project_id"},
        "ssh": {"provider"},
    }[provider]
    if not isinstance(connection, dict) or set(connection) != expected or connection["provider"] != provider:
        raise ValueError("Invalid provider connection")
    for key, value in connection.items():
        string(value, f"connection.{key}")
    if provider == "aws" and not re.fullmatch(r"\d{12}", connection["account_id"]):
        raise ValueError("AWS account_id must have 12 digits")
    transport = target["transport"]
    allowed_transport = {"kind", "user", "instance", "zone"} if transport.get("kind") == "gcp-iap" else {"kind", "user"}
    if set(transport) != allowed_transport or transport["kind"] not in {"ssh", "gcp-iap"}:
        raise ValueError("Invalid transport")
    if transport["kind"] == "gcp-iap" and provider != "gcp":
        raise ValueError("GCP IAP transport requires a GCP target")
    for key, value in transport.items():
        string(value, f"transport.{key}")
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", transport["user"]):
        raise ValueError("Invalid SSH user")
    application = target["application"]
    if not {"env_file", "tls"} <= set(application) <= {"env_file", "tls", "proxy_cidrs"} or application["tls"] not in {
        "direct",
        "external",
    }:
        raise ValueError("Invalid application configuration")
    cidrs = application.get("proxy_cidrs", [])
    if not isinstance(cidrs, list) or any(not isinstance(item, str) for item in cidrs):
        raise ValueError("proxy_cidrs must be a list of network addresses")
    if any(ipaddress.ip_network(item, strict=False).prefixlen == 0 for item in cidrs):
        raise ValueError("A wildcard cannot be a trusted proxy")
    if application["tls"] == "external" and not cidrs:
        raise ValueError("External TLS requires explicitly trusted proxy addresses")
    env_file = (ROOT / string(application["env_file"], "application.env_file")).resolve()
    if not env_file.is_relative_to(ROOT) or not env_file.is_file():
        raise ValueError("Application env_file must be a tracked repository file")
    secrets = target["secrets"]
    if secrets.get("kind") == "files":
        if set(secrets) != {"kind"}:
            raise ValueError("File secrets use the private operator directory")
    elif secrets.get("kind") == "gcp":
        if provider != "gcp" or set(secrets) != {"kind", "names"} or set(secrets["names"]) != set(SECRET_FILES):
            raise ValueError("Invalid GCP secret selection")
        for value in secrets["names"].values():
            if not re.fullmatch(r"[A-Za-z0-9_-]+", string(value, "secret name")):
                raise ValueError("Invalid secret name")
    else:
        raise ValueError("Secrets must select files or GCP Secret Manager")
    infrastructure = target["infrastructure"]
    if infrastructure.get("kind") not in {"aws", "prepared"}:
        raise ValueError("Infrastructure must select AWS provisioning or a prepared VM")
    if infrastructure["kind"] == "aws" and provider != "aws":
        raise ValueError("AWS provisioning requires an AWS target")
    return {**target, "_source": str(source), "_env_file": str(env_file)}


def operator_root(target: dict[str, Any]) -> Path:
    selected = os.environ.get("CORNERSTONE_OPERATOR_ROOT", str(Path.home() / ".config/cornerstone" / target["id"]))
    path = absolute(selected, "CORNERSTONE_OPERATOR_ROOT")
    if path.resolve().is_relative_to(ROOT) or ROOT.is_relative_to(path.resolve()):
        raise ValueError("Operator state and secrets must remain outside the checkout")
    return path


def binding(target: dict[str, Any]) -> dict[str, Any]:
    data = read_json(private_file(operator_root(target) / "host.json"))
    if data.get("target_id") != target["id"] or data.get("provider") != target["provider"]:
        raise ValueError("Private host binding belongs to another target")
    string(data.get("hostname"), "binding.hostname")
    private_file(absolute(data.get("key_file"), "binding.key_file"))
    private_file(absolute(data.get("known_hosts_file"), "binding.known_hosts_file"))
    return data


class Cloud:
    def __init__(self, target: dict[str, Any]):
        self.target = target
        self.env = os.environ.copy()
        if target["provider"] != "ssh":
            result = read_connection(target)
            self.env = {key: value for key, value in self.env.items() if key not in result["unset"]}
            self.env.update(result["environment"])

    def aws(self, service: str, *args: str) -> dict[str, Any]:
        if self.target["provider"] != "aws":
            raise ValueError("AWS operation selected for another provider")
        command = [
            "aws",
            "--region",
            "us-east-1" if service == "pricing" else self.target["connection"]["region"],
            "--no-cli-pager",
            service,
            *args,
            "--output",
            "json",
        ]
        return json.loads(subprocess.check_output(command, env=self.env, text=True) or "{}")

    def gcloud(self, *args: str) -> list[str]:
        connection = self.target["connection"]
        return [
            "gcloud",
            "--configuration=" + connection["profile"],
            "--account=" + connection["account"],
            "--project=" + connection["project_id"],
            *args,
        ]

    def verify_host(self) -> None:
        if self.target["transport"]["kind"] == "gcp-iap":
            data = json.loads(
                subprocess.check_output(
                    self.gcloud(
                        "compute",
                        "instances",
                        "describe",
                        self.target["transport"]["instance"],
                        "--zone=" + self.target["transport"]["zone"],
                        "--format=json",
                    ),
                    env=self.env,
                    text=True,
                )
            )
            if data["status"] != "RUNNING" or (
                self.target["infrastructure"].get("instance_id")
                and data["id"] != self.target["infrastructure"]["instance_id"]
            ):
                raise ValueError("Selected GCP VM identity or power state differs")
        elif self.target["provider"] == "aws":
            host = binding(self.target)
            data = self.aws("ec2", "describe-instances", "--instance-ids", host["instance_id"])
            instances = [item for reservation in data["Reservations"] for item in reservation["Instances"]]
            if len(instances) != 1:
                raise ValueError("AWS host lookup did not identify one VM")
            instance = instances[0]
            tags = {tag["Key"]: tag["Value"] for tag in instance.get("Tags", [])}
            if (
                instance["State"]["Name"] != "running"
                or instance.get("PublicIpAddress") != host["hostname"]
                or tags.get("CornerstoneTarget") != self.target["id"]
            ):
                raise ValueError("AWS VM identity, target tag, power state or address differs from its private binding")
        else:
            binding(self.target)

    def ssh_options(self) -> list[str]:
        host = binding(self.target)
        return [
            "-i",
            host["key_file"],
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            "ConnectTimeout=20",
            "-o",
            "UserKnownHostsFile=" + host["known_hosts_file"],
            "-o",
            "HostKeyAlias=" + host.get("instance_id", self.target["id"]),
        ]

    def remote_command(self, command: str) -> list[str]:
        transport = self.target["transport"]
        if transport["kind"] == "gcp-iap":
            return self.gcloud(
                "compute",
                "ssh",
                f"{transport['user']}@{transport['instance']}",
                "--zone=" + transport["zone"],
                "--tunnel-through-iap",
                "--command=" + command,
            )
        host = binding(self.target)
        return ["ssh", "-T", *self.ssh_options(), f"{transport['user']}@{host['hostname']}", command]

    def run(self, command: str, **kwargs: Any) -> subprocess.CompletedProcess[Any]:
        return subprocess.run(self.remote_command(command), env=self.env, check=True, **kwargs)

    def copy(self, source: str, destination: str, *, download: bool = False) -> None:
        transport = self.target["transport"]
        remote_path = source if download else destination
        absolute(remote_path, "remote transfer path")
        if transport["kind"] == "gcp-iap":
            remote = f"{transport['user']}@{transport['instance']}:{remote_path}"
            command = self.gcloud(
                "compute",
                "scp",
                remote if download else source,
                destination if download else remote,
                "--zone=" + transport["zone"],
                "--tunnel-through-iap",
                "--quiet",
            )
        else:
            host = binding(self.target)
            remote = f"{transport['user']}@{host['hostname']}:{remote_path}"
            command = [
                "scp",
                "-q",
                *self.ssh_options(),
                remote if download else source,
                destination if download else remote,
            ]
        subprocess.run(command, env=self.env, check=True)

    def secret(self, key: str, *, check: bool = False) -> bytes:
        if key not in SECRET_FILES:
            raise ValueError("Unknown secret kind")
        if self.target["secrets"]["kind"] == "files":
            path = private_file(operator_root(self.target) / "secrets" / SECRET_FILES[key])
            return b"" if check else path.read_bytes()
        name = self.target["secrets"]["names"][key]
        args = (
            ("secrets", "describe", name) if check else ("secrets", "versions", "access", "latest", "--secret=" + name)
        )
        return subprocess.check_output(self.gcloud(*args), env=self.env)


def read_connection(target: dict[str, Any]) -> dict[str, Any]:
    connection = target["connection"]
    result = json.loads(
        subprocess.check_output(
            [
                sys.executable,
                str(ROOT / "dev/devkit/cloudctl"),
                "context",
                "--request-json",
                json.dumps(connection),
                "--json",
            ],
            text=True,
        )
    )
    if result.get("version") != 1 or any(
        result.get("connection", {}).get(key) != value for key, value in connection.items()
    ):
        raise ValueError("DevKit returned another provider identity")
    if not isinstance(result.get("unset"), list) or not isinstance(result.get("environment"), dict):
        raise ValueError("Invalid DevKit context")
    return result


def application_env(target: dict[str, Any]) -> dict[str, str]:
    values = {}
    for line in Path(target["_env_file"]).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator or not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            raise ValueError("Application env file contains an invalid assignment")
        if key.startswith(("GCP_", "AWS_", "AZURE_", "CLOUD", "VM_SSH_")) or "PASSWORD" in key or "SECRET" in key:
            raise ValueError(f"Cloud identity and credentials do not belong in application env: {key}")
        tokens = shlex.split(value, comments=False)
        values[key] = tokens[0] if len(tokens) == 1 else "" if not tokens else value
    for key in (
        "VM_DOMAIN",
        "VM_APP_ROOT",
        "VM_KEEP_RELEASES",
        "CORNERSTONE_POSTGRES_DB",
        "CORNERSTONE_POSTGRES_ADMIN_USER",
        "CORNERSTONE_POSTGRES_APP_USER",
    ):
        string(values.get(key), key)
    for key in (
        "VM_APP_ROOT",
        "CORNERSTONE_RUNTIME_DATA_ROOT",
        "CORNERSTONE_POSTGRES_DATA_DIR",
        "CORNERSTONE_ARTIFACTS_DIR",
        "CORNERSTONE_EXPORTS_DIR",
    ):
        absolute(values.get(key), key)
    if not re.fullmatch(r"[a-z0-9.-]+\.[a-z]{2,}", values["VM_DOMAIN"]):
        raise ValueError("Invalid application domain")
    if values.get("CORNERSTONE_FRONTEND_PUBLIC_URL") != "https://" + values["VM_DOMAIN"]:
        raise ValueError("Public origin and domain must match")
    return values


def compose_command(release: str, *args: str) -> str:
    absolute(release, "remote release")
    script = (
        "set -euo pipefail; cd "
        + shlex.quote(release)
        + '; source deploy/vm/lib.sh; deploy_vm_init; deploy_vm_load_runtime_env; deploy_vm_compose "$@"'
    )
    return "sudo -n bash -c " + shlex.quote(script) + " -- " + shlex.join(args)


def export_env(target: dict[str, Any]) -> str:
    values = application_env(target)
    values.update(
        {
            "DEPLOY_PROVIDER": target["provider"],
            "DEPLOY_TARGET_ID": target["id"],
            "CLOUD_TARGET": target["_source"],
            "VM_TRANSPORT": target["transport"]["kind"],
            "DEPLOY_OPERATOR_ROOT": str(operator_root(target)),
            "DEPLOY_CONNECTION_PROFILE": target["connection"].get("profile", "prepared SSH"),
            "DEPLOY_ACCOUNT_SCOPE": target["connection"].get(
                "account_id",
                target["connection"].get("project_id", target["connection"].get("subscription_id", "prepared SSH")),
            ),
            "DEPLOY_SECRET_SOURCE": target["secrets"]["kind"],
            "CORNERSTONE_HTTP_BIND": "127.0.0.1" if target["application"]["tls"] == "direct" else "0.0.0.0",
            "CORNERSTONE_HTTP_PORT": "8080" if target["application"]["tls"] == "direct" else "80",
            "CORNERSTONE_TRUSTED_PROXY_CIDRS": ",".join(target["application"].get("proxy_cidrs", [])),
            "CORNERSTONE_TLS_MODE": target["application"]["tls"],
            "CORNERSTONE_TLS_DOMAIN": values["VM_DOMAIN"],
        }
    )
    return "\n".join(f"export {key}={shlex.quote(value)}" for key, value in values.items())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=[
            "env",
            "context",
            "setup",
            "doctor",
            "run",
            "put",
            "get",
            "secret-read",
            "secret-check",
            "cloud-plan",
            "cloud-create",
            "proxy-check",
            "status",
        ],
    )
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    target = load_target()
    if args.action == "env":
        print(export_env(target))
        return
    if args.action == "context":
        print(json.dumps(target, indent=2))
        return
    if args.action == "setup":
        if target["provider"] == "ssh":
            print("Prepared SSH targets use their private host.json, key and verified known_hosts")
            return
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "dev/devkit/cloudctl"),
                "setup",
                "--request-json",
                json.dumps(target["connection"]),
            ],
            check=True,
        )
        return
    if args.action in {"cloud-plan", "cloud-create"}:
        from aws_host import create_host, plan_host

        (plan_host if args.action == "cloud-plan" else create_host)(target)
        return
    cloud = Cloud(target)
    if args.action in {"secret-read", "secret-check"}:
        sys.stdout.buffer.write(cloud.secret(args.arguments[0], check=args.action == "secret-check"))
        return
    cloud.verify_host()
    if args.action == "proxy-check":
        if target["provider"] == "gcp" and target["infrastructure"].get("backend_service"):
            expected = target["infrastructure"]["minimum_timeout_seconds"]
            result = subprocess.check_output(
                cloud.gcloud(
                    "compute",
                    "backend-services",
                    "describe",
                    target["infrastructure"]["backend_service"],
                    "--global",
                    "--format=value(timeoutSec)",
                ),
                env=cloud.env,
                text=True,
            )
            if int(result.strip()) < expected:
                raise ValueError("Selected GCP backend timeout is too short for application streaming")
        return
    if args.action == "doctor":
        print(f"Verified {target['id']} provider identity and selected host")
    elif args.action == "status":
        cloud.run(compose_command(application_env(target)["VM_APP_ROOT"] + "/current", "ps"))
    elif args.action == "run":
        cloud.run(args.arguments[0])
    elif args.action in {"put", "get"}:
        cloud.copy(*args.arguments, download=args.action == "get")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        print(f"[deploy/host] {exc}", file=sys.stderr)
        raise SystemExit(2) from None
