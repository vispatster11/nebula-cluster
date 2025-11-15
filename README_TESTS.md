Docker-based tests

Run the service and tests entirely in Docker (no host Python needed).

To run:

```powershell
# From repository root
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

- `app` service builds and exposes the application on port 8080
- `tester` service runs the `test_api.sh` script against the app

Notes:
- The test runner accepts `BASE_URL` via environment variable; docker-compose sets it to `http://app:8080`.
- Test artifacts (SQLite `app.db`) are inside the app container and isolated from host.
