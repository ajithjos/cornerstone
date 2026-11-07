"""Only matched, verified application state may enter a fresh deployment."""

import io
import json
import os
import shlex
import subprocess
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
import aws_host  # noqa: E402
import host  # noqa: E402
import package_release  # noqa: E402
import state_transfer as transfer  # noqa: E402


def test_remote_compose_uses_the_installed_runtime_library_and_preserves_stdin(tmp_path):
    vm = tmp_path / "release/deploy/vm"
    vm.mkdir(parents=True)
    (vm / "lib.sh").write_text(
        "deploy_vm_init() { :; }\ndeploy_vm_load_runtime_env() { :; }\n"
        'deploy_vm_compose() { printf "argument=%s\\n" "$1"; cat; }\n'
    )
    binaries = tmp_path / "bin"
    binaries.mkdir()
    sudo = binaries / "sudo"
    sudo.write_text('#!/bin/sh\n[ "$1" = "-n" ] && shift\nexec "$@"\n')
    sudo.chmod(0o700)
    command = host.compose_command(str(tmp_path / "release"), "value with spaces; $(literal)")
    result = subprocess.run(
        ["bash", "-c", command],
        input=b"preserved input",
        capture_output=True,
        env=os.environ | {"PATH": str(binaries) + ":" + os.environ["PATH"]},
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == b"argument=value with spaces; $(literal)\npreserved input"


@pytest.mark.parametrize("name", ["../../etc/passwd", "/etc/passwd", "var/lib/another-app/file"])
def test_transfer_rejects_outside_paths(tmp_path, name):
    archive = tmp_path / "state.tar.gz"
    with tarfile.open(archive, "w:gz") as output:
        entry = tarfile.TarInfo(name)
        output.addfile(entry)
    with pytest.raises(ValueError, match="outside"):
        transfer.validate_archive(archive, ["/var/lib/cornerstone"])


def test_transfer_rejects_symlinks_and_allows_frontend_relative_root(tmp_path):
    archive = tmp_path / "frontend.tar.gz"
    with tarfile.open(archive, "w:gz") as output:
        output.addfile(tarfile.TarInfo("./index.html"))
    transfer.validate_archive(archive, ["."])
    with tarfile.open(archive, "w:gz") as output:
        entry = tarfile.TarInfo("./link")
        entry.type = tarfile.SYMTYPE
        entry.linkname = "/etc"
        output.addfile(entry)
    with pytest.raises(ValueError, match="link/device"):
        transfer.validate_archive(archive, ["."])


def test_migration_keeps_all_credentials_policy_and_unknown_settings():
    source = {
        "CORNERSTONE_FRONTEND_PUBLIC_URL": "https://scholahouse.com",
        "CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID": "original-client",
        "CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET": "original secret",
        "CORNERSTONE_POSTGRES_APP_PASSWORD": "original database secret",
        "CORNERSTONE_DATABASE_URL": "original database URL",
        "CORNERSTONE_FUTURE_OPTION": "preserve this too",
    }
    result = transfer.migration_runtime(
        "".join(f"{key}={shlex.quote(value)}\n" for key, value in source.items()),
        {"tls": "direct", "runtime_root": "/var/lib/cornerstone", "caddy_image": "test-image"},
        "/opt/cornerstone/releases/test",
        {"images": {"postgres": "sha256:pg", "frontend": "sha256:web"}},
    )
    assert all(result[key] == value for key, value in source.items())
    assert result["CORNERSTONE_HTTP_BIND"] == "127.0.0.1"
    assert result["CORNERSTONE_TLS_DOMAIN"] == "scholahouse.com"


def test_bad_checksum_prevents_cloud_access(tmp_path, monkeypatch):
    monkeypatch.setattr(transfer, "application_env", lambda _: {})
    monkeypatch.setattr(transfer, "committed_application", lambda: {})
    (tmp_path / "manifest.json").write_text(
        json.dumps(
            {
                "version": 1,
                "application": {},
                "application_source": {},
                "transfers": {
                    name: "wrong"
                    for name in ["database.dump", "files.tar.gz", "frontend.tar.gz", "application-image.tar.gz"]
                },
            }
        )
    )
    (tmp_path / "database.dump").write_bytes(b"changed")
    monkeypatch.setattr(transfer, "Cloud", lambda _: pytest.fail("Cloud must not be accessed"))
    with pytest.raises(ValueError, match="checksum mismatch"):
        transfer.import_state({}, tmp_path)


def test_release_package_omits_untracked_secrets_and_contains_explicit_frontend(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    repo.mkdir()
    (repo / "tracked").write_text("application")
    (repo / "untracked-secret").write_text("private")
    frontend = tmp_path / "frontend"
    frontend.mkdir()
    (frontend / "index.html").write_text("preserved frontend")
    monkeypatch.setattr(package_release, "ROOT", repo)
    monkeypatch.setattr(package_release.subprocess, "check_output", lambda *a, **k: b"tracked\0")
    output = tmp_path / "release.tar.gz"
    package_release.package(output, frontend)
    with tarfile.open(output) as archive:
        assert "tracked" in archive.getnames()
        assert "untracked-secret" not in archive.getnames()
        assert archive.extractfile(str(package_release.FRONTEND / "index.html")).read() == b"preserved frontend"


def test_ip_quota_failure_cannot_launch_a_paid_vm(tmp_path, monkeypatch):
    target = host.load_target()
    monkeypatch.setenv("CORNERSTONE_OPERATOR_ROOT", str(tmp_path))
    plan = {
        "target_sha256": aws_host.digest(target),
        "account_id": target["connection"]["account_id"],
        "operator_cidr": "192.0.2.1/32",
        "key_file": str(tmp_path / "key"),
        "image_id": "ami-test",
        "root_device": "/dev/sda1",
        "client_token": "test",
    }
    (tmp_path / "provision-plan.json").write_text(json.dumps(plan))
    (tmp_path / "provision-progress.json").write_text(
        json.dumps({"target_sha256": aws_host.digest(target), "key_name": "test", "security_group_id": "sg-test"})
    )
    calls = []

    class FakeCloud:
        def __init__(self, _):
            pass

        def aws(self, service, action, *args):
            calls.append(action)
            if action == "describe-security-groups":
                return {
                    "SecurityGroups": [
                        {
                            "IpPermissions": [
                                {"IpProtocol": "tcp", "FromPort": port, "ToPort": port, "IpRanges": [{"CidrIp": cidr}]}
                                for port, cidr in [(22, "192.0.2.1/32"), (80, "0.0.0.0/0"), (443, "0.0.0.0/0")]
                            ]
                        }
                    ]
                }
            if action == "describe-addresses":
                return {"Addresses": []}
            if action == "allocate-address":
                raise ValueError("IP quota exceeded")
            if action == "run-instances":
                return {"Instances": [{"InstanceId": "i-unwanted"}]}
            raise AssertionError(action)

    monkeypatch.setattr(aws_host, "Cloud", FakeCloud)
    monkeypatch.setattr(aws_host, "urlopen", lambda *a, **k: io.BytesIO(b"192.0.2.1"))
    with pytest.raises(ValueError, match="quota"):
        aws_host.create_host(target)
    assert "run-instances" not in calls


@pytest.mark.parametrize("tls", ["direct", "external"])
def test_vm_startup_reuses_preserved_image_and_starts_tls_only_when_selected(tmp_path, tls):
    repo = Path(__file__).resolve().parents[1]
    binaries = tmp_path / "bin"
    binaries.mkdir()
    events = tmp_path / "events"
    for command in ["docker", "chown"]:
        file = binaries / command
        file.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$EVENTS"\n')
        file.chmod(0o700)
    values = host.application_env(host.load_target()) | {
        "CORNERSTONE_POSTGRES_DATA_DIR": str(tmp_path / "pg"),
        "CORNERSTONE_ARTIFACTS_DIR": str(tmp_path / "artifacts"),
        "CORNERSTONE_EXPORTS_DIR": str(tmp_path / "exports"),
        "CORNERSTONE_RUNTIME_DATA_ROOT": str(tmp_path / "data"),
        "CORNERSTONE_DATABASE_URL": "test-database-url",
        "CORNERSTONE_WORKSPACE_HOST": str(repo),
        "CORNERSTONE_FRONTEND_BUILD_HOST": str(tmp_path / "web"),
        "CORNERSTONE_POSTGRES_ADMIN_PASSWORD": "real-test-admin-value",
        "CORNERSTONE_POSTGRES_APP_PASSWORD": "real-test-app-value",
        "CORNERSTONE_TLS_MODE": tls,
    }
    runtime = tmp_path / "runtime.env"
    runtime.write_text("".join(f"{key}={shlex.quote(value)}\n" for key, value in values.items()))
    result = subprocess.run(
        ["bash", str(repo / "deploy/vm/setup.sh"), "--skip-build"],
        env=os.environ
        | {
            "PATH": str(binaries) + ":" + os.environ["PATH"],
            "EVENTS": str(events),
            "DEPLOY_VM_ENV_FILE": str(runtime),
            "ROOT_DIR": str(repo),
        },
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    log = events.read_text()
    assert "--build" not in log
    assert "--wait postgres control-plane frontend" in log
    assert ("--profile https up -d https" in log) == (tls == "direct")
