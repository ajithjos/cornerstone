# Live Frontend Backend Stack

This mode runs only the backend dependencies in Docker:

- `postgres`
- `control-plane`

It is intended for frontend live iteration with `flutter run` on a separate local port.

Use this mode when you want hot reload and fast UI iteration while keeping backend behavior stable.

For production-matching integrated flow, use `deploy/dev/setup.sh` (or `make dev-up`) instead.