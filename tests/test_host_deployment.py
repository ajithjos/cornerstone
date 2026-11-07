"""Deployment admission and identity checks must precede remote changes."""

import importlib.util
import json
import sys
from pathlib import Path

import pytest

DEPLOY = Path(__file__).resolve().parents[1] / "deploy"
sys.path.insert(0, str(DEPLOY))
spec = importlib.util.spec_from_file_location("cornerstone_host", DEPLOY / "host.py")
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
from aws_host import owned, provision_spec  # noqa: E402


def selected(tmp_path, provider="aws"):
    data = json.loads((DEPLOY / "config/environments" / f"prod.{provider}.json").read_text())
    path = tmp_path / "target.json"
    path.write_text(json.dumps(data))
    return path, data


def test_target_provider_mismatch_and_unknown_fields_fail_before_cloud_access(tmp_path):
    path, data = selected(tmp_path)
    with pytest.raises(ValueError, match="provider must match"):
        host.load_target(str(path), "gcp")
    data["unexpected"] = True
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="exact version-1"):
        host.load_target(str(path), "aws")


def test_target_application_file_cannot_escape_repository(tmp_path):
    path, data = selected(tmp_path)
    data["application"]["env_file"] = str(tmp_path / "other.env")
    path.write_text(json.dumps(data))
    with pytest.raises(ValueError, match="repository file"):
        host.load_target(str(path), "aws")


def test_operator_state_rejects_checkout_and_relative_paths(tmp_path, monkeypatch):
    target = host.load_target()
    monkeypatch.setenv("CORNERSTONE_OPERATOR_ROOT", str(DEPLOY / "private"))
    with pytest.raises(ValueError, match="outside the checkout"):
        host.operator_root(target)
    monkeypatch.setenv("CORNERSTONE_OPERATOR_ROOT", "relative")
    with pytest.raises(ValueError, match="absolute"):
        host.operator_root(target)


def test_private_secret_requires_owner_only_regular_file(tmp_path):
    path = tmp_path / "secret.json"
    host.private_write(path, '{"private":"fixture"}')
    assert path.stat().st_mode & 0o777 == 0o600
    path.chmod(0o644)
    with pytest.raises(ValueError, match="owner-only"):
        host.private_file(path)
    path.chmod(0o600)
    link = tmp_path / "link"
    link.symlink_to(path)
    with pytest.raises(ValueError, match="regular"):
        host.private_file(link)


def test_transport_preserves_command_as_one_argument_and_enforces_host_key_checks(tmp_path, monkeypatch):
    target = host.load_target()
    root = tmp_path / "operator"
    root.mkdir()
    key, known = root / "key", root / "known"
    host.private_write(key, "fixture")
    host.private_write(known, "fixture")
    host.private_write(
        root / "host.json",
        json.dumps(
            {
                "target_id": target["id"],
                "provider": "aws",
                "hostname": "192.0.2.15",
                "key_file": str(key),
                "known_hosts_file": str(known),
                "instance_id": "i-test",
            }
        ),
    )
    monkeypatch.setenv("CORNERSTONE_OPERATOR_ROOT", str(root))
    cloud = object.__new__(host.Cloud)
    cloud.target = target
    command = "sudo -n bash /tmp/script --name 'a b; $(literal)'"
    argv = cloud.remote_command(command)
    assert argv[-1] == command
    assert "StrictHostKeyChecking=yes" in argv
    assert "HostKeyAlias=i-test" in argv
    assert "BatchMode=yes" in argv
    assert argv[-2] == "ubuntu@192.0.2.15"


def test_aws_wrong_target_tag_cannot_reach_remote_host(tmp_path, monkeypatch):
    target = host.load_target()
    monkeypatch.setattr(host, "binding", lambda _: {"instance_id": "i-test", "hostname": "192.0.2.15"})
    cloud = object.__new__(host.Cloud)
    cloud.target = target
    cloud.aws = lambda *args: {
        "Reservations": [
            {
                "Instances": [
                    {
                        "State": {"Name": "running"},
                        "PublicIpAddress": "192.0.2.15",
                        "Tags": [{"Key": "CornerstoneTarget", "Value": "another-target"}],
                    }
                ]
            }
        ]
    }
    with pytest.raises(ValueError, match="identity"):
        cloud.verify_host()


def test_provisioning_never_adopts_an_unowned_named_resource():
    with pytest.raises(ValueError, match="unowned"):
        owned([{"Tags": [{"Key": "Name", "Value": "same-name"}]}], "target")
    with pytest.raises(ValueError, match="at most one"):
        owned([{}, {}], "target")


def test_host_provisioning_bounds_capacity_before_cloud_calls():
    target = host.load_target()
    target["infrastructure"]["disk_gb"] = -1
    with pytest.raises(ValueError, match="bounded"):
        provision_spec(target)


def test_gcp_and_aws_share_application_state_paths_and_keep_tls_selection_separate():
    aws = host.load_target(provider="aws")
    gcp = host.load_target(provider="gcp")
    assert host.application_env(aws) == host.application_env(gcp)
    assert "CORNERSTONE_HTTP_BIND=127.0.0.1" in host.export_env(aws)
    assert "CORNERSTONE_HTTP_BIND=0.0.0.0" in host.export_env(gcp)
    assert "DEPLOY_ACCOUNT_SCOPE=p601-ephphatha-host" in host.export_env(gcp)
