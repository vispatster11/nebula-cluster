# Wiki Service - FastAPI REST API

FastAPI REST API with PostgreSQL backend, Prometheus `/metrics` endpoint. Part of wiki-chart Helm deployment.

## Local Development (without k3d)
```bash
# Install deps
pip install -r requirements.txt

# Start PostgreSQL
docker run -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=wiki -p 5432:5432 postgres:15-alpine

# Run API
uvicorn main:app --reload
```
API: `http://localhost:8000` | Docs: `http://localhost:8000/docs`

## API Endpoints
- `POST /users` — Create user
- `GET /user/{id}` — Get user
- `POST /posts` — Create post
- `GET /posts/{id}` — Get post
- `GET /metrics` — Prometheus metrics

For full deployment, see root `README.md`.
curl http://localhost:8000/metrics
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DB_USER` | `postgres` | PostgreSQL username |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `wiki` | Database name |

## Build Docker Image

```bash
docker build -t wiki-service:0.1.0 .
```

Multi-stage build, runs as non-root user.

## Deploy to Kubernetes

Use Helm chart in `../wiki-chart/`.

## Architecture

- **FastAPI** — HTTP server
- **SQLAlchemy + asyncpg** — Async ORM for PostgreSQL
- **Prometheus Client** — Metrics counters
- **Uvicorn** — ASGI server
