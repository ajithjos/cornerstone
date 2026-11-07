"""Preserve a frozen Cornerstone release, its credentials and all live application state."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import shlex
import subprocess
import tarfile
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath
from typing import Any

from host import ROOT, Cloud, absolute, application_env, load_target, operator_root, private_write
from host import compose_command as compose
from package_release import FRONTEND, package

DATABASE_STATE_SQL = r"""
SELECT format(
 'SELECT json_build_object(''table'',%L,''rows'',count(*),''digest'',md5(coalesce('
 'string_agg(row_to_json(t)::text,E''\n'' ORDER BY row_to_json(t)::text),''''))) FROM %I.%I t;',
 tablename, schemaname, tablename
) FROM pg_tables WHERE schemaname='public' ORDER BY tablename
\gexec
SELECT json_build_object('sequence',sequencename,'last_value',last_value)
FROM pg_sequences WHERE schemaname='public' ORDER BY sequencename;
"""

FILE_SCAN = """
import hashlib,json,os,pathlib,stat,sys
records=[]
for root in json.loads(sys.argv[1]):
    for directory,dirs,files in os.walk(root,followlinks=False):
        for name in sorted(dirs+files):
            path=pathlib.Path(directory)/name
            info=path.lstat()
            entry={'path':str(path),'mode':stat.S_IMODE(info.st_mode),'uid':info.st_uid,'gid':info.st_gid}
            if stat.S_ISDIR(info.st_mode):
                entry['kind']='directory'
            elif stat.S_ISREG(info.st_mode):
                entry['kind']='file'
                digest=hashlib.sha256()
                with path.open('rb') as stream:
                    for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
                entry['sha256']=digest.hexdigest()
            else:
                raise SystemExit('State transfer requires an explicit policy for non-regular entry: '+str(path))
            records.append(entry)
print(json.dumps(sorted(records,key=lambda x:x['path'])))
"""


def checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def runtime_env(text: str) -> dict[str, str]:
    values = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep:
            tokens = shlex.split(value)
            values[key] = tokens[0] if len(tokens) == 1 else "" if not tokens else value
    return values


def database_state(cloud: Cloud, release: str) -> list[dict[str, Any]]:
    command = compose(
        release,
        "exec",
        "-T",
        "postgres",
        "sh",
        "-c",
        'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -qAt -v ON_ERROR_STOP=1',
    )
    result = cloud.run(command, input=DATABASE_STATE_SQL.encode(), capture_output=True)
    return [json.loads(line) for line in result.stdout.decode().splitlines() if line]


def file_state(cloud: Cloud, roots: list[str]) -> list[dict[str, Any]]:
    command = "sudo -n python3 -c " + shlex.quote(FILE_SCAN) + " " + shlex.quote(json.dumps(roots))
    return json.loads(cloud.run(command, capture_output=True).stdout)


def state_roots(values: dict[str, str]) -> list[str]:
    return [values[key] for key in ["CORNERSTONE_ARTIFACTS_DIR", "CORNERSTONE_EXPORTS_DIR"]]


def validate_archive(path: Path, roots: list[str]) -> None:
    allowed = [PurePosixPath(root.lstrip("/")) for root in roots]
    with tarfile.open(path, "r:gz") as archive:
        for item in archive.getmembers():
            name = PurePosixPath(item.name)
            if (
                name.is_absolute()
                or ".." in name.parts
                or not any(name == root or root in name.parents for root in allowed)
            ):
                raise ValueError(f"Archive entry is outside the owned roots: {name}")
            if not item.isfile() and not item.isdir():
                raise ValueError(f"Archive link/device requires an explicit policy: {name}")


def workarea(selected: str) -> Path:
    path = absolute(selected, "workarea")
    if path.resolve().is_relative_to(ROOT) or ROOT.is_relative_to(path.resolve()):
        raise ValueError("Transfer artifacts must remain outside Git")
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.stat().st_mode & 0o077:
        raise ValueError("Transfer workarea must be owner-only")
    return path


def private_bytes(path: Path, data: bytes) -> None:
    with path.open("xb") as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(data)


def committed_application() -> dict[str, str]:
    data = subprocess.check_output(
        [
            "git",
            "-C",
            str(ROOT),
            "archive",
            "HEAD",
            "rust",
            "content",
            "fe/flutter/apps/cornerstone",
            "deploy/config/runtime_defaults",
        ]
    )
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        hashes = {}
        for item in archive:
            if item.isfile():
                source = archive.extractfile(item)
                if source is None:
                    raise ValueError("Committed application file is unreadable: " + item.name)
                with source:
                    hashes[item.name] = hashlib.sha256(source.read()).hexdigest()
        return hashes


def application_state(cloud: Cloud, release: str, paths: list[str]) -> dict[str, str]:
    script = (
        "import pathlib,hashlib,json,sys;root=pathlib.Path(sys.argv[1]);"
        "print(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() "
        "for p in json.load(sys.stdin)}))"
    )
    return json.loads(
        cloud.run(
            "sudo -n python3 -c " + shlex.quote(script) + " " + shlex.quote(release),
            input=json.dumps(paths).encode(),
            capture_output=True,
        ).stdout
    )


def export_state(target: dict[str, Any], root: Path) -> None:
    if any(root.iterdir()):
        raise ValueError("Use a fresh transfer workarea; never overwrite recovery artifacts")
    cloud = Cloud(target)
    cloud.verify_host()
    values = application_env(target)
    release = cloud.run(
        "readlink -f " + shlex.quote(values["VM_APP_ROOT"] + "/current"), capture_output=True, text=True
    ).stdout.strip()
    if not release.startswith(values["VM_APP_ROOT"] + "/releases/release-") or "/" in release.removeprefix(
        values["VM_APP_ROOT"] + "/releases/"
    ):
        raise ValueError("Current source release is outside its owned directory")
    expected = committed_application()
    actual_source = application_state(cloud, release, list(expected))
    source_changes = [path for path in expected if actual_source[path] != expected[path]]
    runtime = cloud.run("sudo -n cat " + shlex.quote(release + "/deploy/vm/.env"), capture_output=True).stdout
    raw = runtime_env(runtime.decode())
    for key in [
        "CORNERSTONE_POSTGRES_DB",
        "CORNERSTONE_POSTGRES_ADMIN_USER",
        "CORNERSTONE_POSTGRES_APP_USER",
        "CORNERSTONE_POSTGRES_DATA_DIR",
        "CORNERSTONE_ARTIFACTS_DIR",
        "CORNERSTONE_EXPORTS_DIR",
        "CORNERSTONE_FRONTEND_PUBLIC_URL",
    ]:
        if raw[key] != values[key]:
            raise ValueError("Source state contract differs: " + key)
    private_bytes(root / "runtime.env", runtime)
    project = values["CORNERSTONE_VM_COMPOSE_PROJECT_NAME"]
    images = {}
    for service in ["postgres", "control-plane", "frontend"]:
        image = cloud.run(
            "sudo -n docker inspect --format '{{.Image}}' " + shlex.quote(project + "-" + service + "-1"),
            capture_output=True,
            text=True,
        ).stdout.strip()
        images[service] = image
    marker = values["VM_APP_ROOT"] + "/deploy-state/writes-frozen"
    cloud.run(
        "sudo -n mkdir -p "
        + shlex.quote(values["VM_APP_ROOT"] + "/deploy-state")
        + " && sudo -n chmod 700 "
        + shlex.quote(values["VM_APP_ROOT"] + "/deploy-state")
    )
    cloud.run("sudo -n test ! -e " + shlex.quote(marker))
    if target["application"]["tls"] == "direct":
        cloud.run(compose(release, "--profile", "https", "stop", "https"))
    cloud.run(compose(release, "stop", "frontend", "control-plane"))
    running = cloud.run(
        "sudo -n docker ps --filter label=com.docker.compose.project="
        + shlex.quote(project)
        + " --format '{{.Label \"com.docker.compose.service\"}}'",
        capture_output=True,
        text=True,
    ).stdout.split()
    if set(running) != {"postgres"}:
        raise ValueError("Export requires only PostgreSQL running")
    cloud.run("printf '%s\n' " + shlex.quote(release) + " | sudo -n tee " + shlex.quote(marker) + " >/dev/null")
    database = database_state(cloud, release)
    files = file_state(cloud, state_roots(values))
    private_bytes(
        root / "database.dump",
        cloud.run(
            compose(
                release,
                "exec",
                "-T",
                "postgres",
                "sh",
                "-c",
                'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom',
            ),
            capture_output=True,
        ).stdout,
    )
    names = [value.lstrip("/") for value in state_roots(values)]
    private_bytes(
        root / "files.tar.gz",
        cloud.run("sudo -n tar -czpf - --numeric-owner -C / " + shlex.join(names), capture_output=True).stdout,
    )
    frontend = raw["CORNERSTONE_FRONTEND_BUILD_HOST"]
    private_bytes(
        root / "frontend.tar.gz",
        cloud.run("sudo -n tar -czpf - --numeric-owner -C " + shlex.quote(frontend) + " .", capture_output=True).stdout,
    )
    frontend_files = file_state(cloud, [frontend])
    frontend_hashes = {
        entry["path"].removeprefix(frontend + "/"): entry["sha256"]
        for entry in frontend_files
        if entry["kind"] == "file"
    }
    image_ref = cloud.run(
        "sudo -n docker inspect --format '{{.Config.Image}}' " + shlex.quote(project + "-control-plane-1"),
        capture_output=True,
        text=True,
    ).stdout.strip()
    command = "set -euo pipefail; sudo -n docker image save " + shlex.quote(image_ref) + " | gzip -c"
    private_bytes(root / "application-image.tar.gz", cloud.run(command, capture_output=True).stdout)
    if database_state(cloud, release) != database or file_state(cloud, state_roots(values)) != files:
        raise ValueError("Frozen source state changed during export")
    manifest = {
        "version": 1,
        "source_target": target["id"],
        "source_release": release,
        "application": values,
        "application_source": actual_source,
        "source_reference_changes": source_changes,
        "source_commit_reference": subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True
        ).strip(),
        "images": images,
        "application_image_ref": image_ref,
        "database_state": database,
        "file_state": files,
        "frontend_hashes": frontend_hashes,
        "transfers": {
            name: checksum(root / name)
            for name in ["database.dump", "files.tar.gz", "frontend.tar.gz", "application-image.tar.gz"]
        },
    }
    private_write(root / "manifest.json", json.dumps(manifest, indent=2) + "\n")
    print(
        f"Source frozen and exported: {len(database)} database fingerprints, "
        f"{len(files)} file entries, {len(frontend_hashes)} frontend files; application image preserved."
    )


def migration_runtime(source: str, values: dict[str, str], release: str, manifest: dict[str, Any]) -> dict[str, str]:
    raw = runtime_env(source)
    raw.update(
        {
            "CORNERSTONE_WORKSPACE_HOST": release,
            "CORNERSTONE_FRONTEND_BUILD_HOST": release + "/" + str(FRONTEND),
            "CORNERSTONE_HTTP_BIND": "127.0.0.1" if values["tls"] == "direct" else "0.0.0.0",
            "CORNERSTONE_HTTP_PORT": "8080" if values["tls"] == "direct" else "80",
            "CORNERSTONE_TLS_MODE": values["tls"],
            "CORNERSTONE_TLS_DOMAIN": raw["CORNERSTONE_FRONTEND_PUBLIC_URL"].removeprefix("https://"),
            "CORNERSTONE_RUNTIME_DATA_ROOT": values["runtime_root"],
            "CORNERSTONE_CONTROL_PLANE_IMAGE": "cornerstone-" + release.rsplit("/", 1)[1] + "-control-plane",
            "CORNERSTONE_POSTGRES_IMAGE": "postgres:18-alpine@" + manifest["images"]["postgres"],
            "CORNERSTONE_NGINX_IMAGE": "nginx:1.29-alpine@" + manifest["images"]["frontend"],
            "CORNERSTONE_CADDY_IMAGE": values["caddy_image"],
        }
    )
    return raw


def import_state(target: dict[str, Any], root: Path) -> None:
    manifest = json.loads((root / "manifest.json").read_text())
    values = application_env(target)
    if values != manifest["application"] or committed_application() != manifest["application_source"]:
        raise ValueError("Destination application source or state contract differs from the frozen release")
    required = {"database.dump", "files.tar.gz", "frontend.tar.gz", "application-image.tar.gz"}
    if manifest.get("version") != 1 or set(manifest["transfers"]) != required:
        raise ValueError("Transfer manifest is incomplete or unsupported")
    for name, expected in manifest["transfers"].items():
        if (
            name not in {"database.dump", "files.tar.gz", "frontend.tar.gz", "application-image.tar.gz"}
            or checksum(root / name) != expected
        ):
            raise ValueError("Transfer checksum mismatch: " + name)
    validate_archive(root / "files.tar.gz", state_roots(values))
    validate_archive(root / "frontend.tar.gz", ["."])
    cloud = Cloud(target)
    cloud.verify_host()
    app_root = values["VM_APP_ROOT"]
    revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"], text=True).strip()
    release = app_root + "/releases/release-" + datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + revision
    current = app_root + "/current"
    cloud.run(
        "sudo -n test ! -e "
        + shlex.quote(current)
        + " && sudo -n test ! -L "
        + shlex.quote(current)
        + " && sudo -n test ! -e "
        + shlex.quote(release)
    )
    frontend = root / "frontend"
    admission = (
        "import pathlib,sys;p=pathlib.Path(sys.argv[1]);"
        "assert not p.is_symlink() and (not p.exists() or not any(p.iterdir())),"
        "'Destination database directory already contains state'"
    )
    cloud.run(
        "sudo -n python3 -c " + shlex.quote(admission) + " " + shlex.quote(values["CORNERSTONE_POSTGRES_DATA_DIR"])
    )
    if (root / "import-intent.json").exists():
        raise ValueError("Inspect the retained import intent before recovering an interrupted import")
    private_write(root / "import-intent.json", json.dumps({"target": target["id"], "release": release}) + "\n")
    frontend.mkdir(mode=0o700)
    with tarfile.open(root / "frontend.tar.gz") as archive:
        archive.extractall(frontend, filter="data")
    package(root / "release.tar.gz", frontend)
    runtime_values = {
        "tls": target["application"]["tls"],
        "runtime_root": values["CORNERSTONE_RUNTIME_DATA_ROOT"],
        "caddy_image": runtime_env((ROOT / "deploy/config/build/images.lock.env").read_text())[
            "CORNERSTONE_CADDY_IMAGE"
        ],
    }
    raw = migration_runtime((root / "runtime.env").read_text(), runtime_values, release, manifest)
    private_write(
        root / "destination.env", "".join(key + "=" + shlex.quote(value) + "\n" for key, value in raw.items())
    )
    remote = cloud.run(
        "umask 077; mktemp -d /tmp/cornerstone-state.XXXXXXXXXXXX", capture_output=True, text=True
    ).stdout.strip()
    if not remote.startswith("/tmp/cornerstone-state.") or "/" in remote.removeprefix("/tmp/"):
        raise ValueError("Unexpected remote transfer directory")
    try:
        for name in ["database.dump", "files.tar.gz", "application-image.tar.gz", "release.tar.gz", "destination.env"]:
            cloud.copy(str(root / name), remote + "/" + name)
        cloud.run(
            "sudo -n mkdir -p "
            + shlex.quote(release)
            + " && sudo -n tar -xzpf "
            + shlex.quote(remote + "/release.tar.gz")
            + " -C "
            + shlex.quote(release)
            + " && sudo -n install -m 600 "
            + shlex.quote(remote + "/destination.env")
            + " "
            + shlex.quote(release + "/deploy/vm/.env")
        )
        cloud.run("sudo -n docker image load -i " + shlex.quote(remote + "/application-image.tar.gz"))
        cloud.run(
            "sudo -n docker image tag "
            + shlex.quote(manifest["application_image_ref"])
            + " "
            + shlex.quote(raw["CORNERSTONE_CONTROL_PLANE_IMAGE"])
        )
        imported = cloud.run(
            "sudo -n docker image inspect --format '{{.Id}}' " + shlex.quote(raw["CORNERSTONE_CONTROL_PLANE_IMAGE"]),
            capture_output=True,
            text=True,
        ).stdout.strip()
        if imported != manifest["images"]["control-plane"]:
            raise ValueError("Imported application image identity differs")
        cloud.run(
            "sudo -n mkdir -p "
            + shlex.join(
                [raw["CORNERSTONE_POSTGRES_DATA_DIR"], raw["CORNERSTONE_ARTIFACTS_DIR"], raw["CORNERSTONE_EXPORTS_DIR"]]
            )
        )
        cloud.run("sudo -n tar -xzpf " + shlex.quote(remote + "/files.tar.gz") + " --numeric-owner -C /")
        cloud.run(compose(release, "up", "-d", "--wait", "postgres"))
        restore = (
            'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_restore --exit-on-error --clean --if-exists '
            '--no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
        )
        cloud.run(
            compose(release, "exec", "-T", "postgres", "sh", "-c", restore), input=(root / "database.dump").read_bytes()
        )
        ownership = r"""
SELECT format('ALTER TABLE %I.%I OWNER TO %I', schemaname, tablename, :'app_owner')
FROM pg_tables WHERE schemaname='public'
\gexec
SELECT format('ALTER SEQUENCE %I.%I OWNER TO %I', schemaname, sequencename, :'app_owner')
FROM pg_sequences WHERE schemaname='public'
\gexec
SELECT format('ALTER SCHEMA public OWNER TO %I', :'app_owner')
\gexec
SELECT format('GRANT ALL ON DATABASE %I TO %I', current_database(), :'app_owner')
\gexec
"""
        sql = (
            'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
            '-v ON_ERROR_STOP=1 --set=app_owner="$CORNERSTONE_POSTGRES_APP_USER"'
        )
        cloud.run(compose(release, "exec", "-T", "postgres", "sh", "-c", sql), input=ownership.encode())
        if (
            database_state(cloud, release) != manifest["database_state"]
            or file_state(cloud, state_roots(values)) != manifest["file_state"]
        ):
            raise ValueError("Restored database, sequences or application files differ from the source")
        frontend_files = file_state(cloud, [raw["CORNERSTONE_FRONTEND_BUILD_HOST"]])
        hashes = {
            entry["path"].removeprefix(raw["CORNERSTONE_FRONTEND_BUILD_HOST"] + "/"): entry["sha256"]
            for entry in frontend_files
            if entry["kind"] == "file"
        }
        if hashes != manifest["frontend_hashes"]:
            raise ValueError("Preserved frontend asset hashes differ")
        receipt = {
            "source": manifest["source_target"],
            "destination": target["id"],
            "release": release,
            "image_verified": True,
            "database_verified": True,
            "files_verified": True,
            "frontend_verified": True,
        }
        private_write(root / "import-receipt.json", json.dumps(receipt, indent=2) + "\n")
        cloud.run("sudo -n ln -s " + shlex.quote(release) + " " + shlex.quote(current))
        cloud.run("cd " + shlex.quote(release) + " && sudo -n bash deploy/vm/setup.sh --skip-build")
        receipt["application_started"] = True
        private_write(root / "import-receipt.json", json.dumps(receipt, indent=2) + "\n")
        secrets = {
            key: raw[name]
            for key, name in {
                "postgres_admin_password": "CORNERSTONE_POSTGRES_ADMIN_PASSWORD",
                "postgres_app_password": "CORNERSTONE_POSTGRES_APP_PASSWORD",
                "google_oauth_client_id": "CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID",
                "google_oauth_client_secret": "CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET",
            }.items()
        }
        private_write(operator_root(target) / "secrets/runtime-env.json", json.dumps(secrets) + "\n")
        print("Preserved image, frontend, database, files and sign-in credentials verified; application started.")
    finally:
        cloud.run("sudo -n rm -rf -- " + shlex.quote(remote))


def main() -> None:
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["export", "import"])
    parser.add_argument("--workarea", required=True)
    args = parser.parse_args()
    target, root = load_target(), workarea(args.workarea)
    (export_state if args.action == "export" else import_state)(target, root)


if __name__ == "__main__":
    main()
