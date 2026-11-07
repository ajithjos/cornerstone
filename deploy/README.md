# Deployment

The canonical operator workflow is [VM deployment](../docs/deploy/runbooks/vm-deploy.md). AWS is the default; `CLOUD` and `CLOUD_TARGET` select another provider or prepared Linux VM.

- `deploy/host.py`: target validation, native DevKit cloud identity and verified transport
- `deploy/aws_host.py`: bounded, resumable AWS host provisioning
- `deploy/state_transfer.py`: matched application image, frontend, database and file transfer
- `deploy/package_release.py`: tracked sources and explicit frontend build packaging
- `deploy/config/environments/`: cloud targets and shared application settings
- `deploy/config/build/`: image catalog
- `deploy/config/runtime_defaults/`: bootstrap identity settings
- `deploy/vm/`: shared hosted Compose, startup and deployment
- `deploy/dev/`: local development runtime

Real credentials and private host bindings stay outside Git. The retained GCP secret-administration helper uses `prod.gcp.env` explicitly. The [GCP first-rollout record](../docs/deploy/runbooks/gcp-vm-first-deploy.md) describes that existing provider's infrastructure.
