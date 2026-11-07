# Production Deployment

The canonical production workflow is [VM deployment](../../docs/deploy/runbooks/vm-deploy.md). It owns AWS-default provider targets, private inputs, deployment, preserved-state migration and verification.

The files under `templates/` retain earlier examples; they do not select the current production destination. Active runtime assets live under `deploy/vm/` and tracked targets under `deploy/config/`.
