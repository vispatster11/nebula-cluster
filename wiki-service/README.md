# Wiki Service

FastAPI REST API for users and posts with Prometheus metrics and PostgreSQL.

## Local Setup

**Prerequisites:** Python 3.13, PostgreSQL (or Docker)

**1. Install dependencies:**
```bash
pip install -r requirements.txt
```

**2. Start PostgreSQL:**
```bash
docker run -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=wiki -p 5432:5432 postgres:15-alpine
```

**3. Run the app:**
```bash
uvicorn main:app --reload
```

API: `http://localhost:8000`
Docs: `http://localhost:8000/docs`

## API Endpoints

- `POST /users` — Create user
- `GET /users` — List users
- `GET /user/{id}` — Get user
- `POST /posts` — Create post
- `GET /posts/{id}` — Get post
- `GET /metrics` — Prometheus metrics
- `GET /docs` — Interactive API docs

## Test It

```bash
# Create user
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

# Create post
curl -X POST http://localhost:8000/posts \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "title": "First", "content": "Hello"}'

# View metrics
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

Use Helm chart in `../wiki-chart/`. See `../PIPELINE.md` for instructions.

## Architecture

- **FastAPI** — HTTP server
- **SQLAlchemy + asyncpg** — Async ORM for PostgreSQL
- **Prometheus Client** — Metrics counters
- **Uvicorn** — ASGI server
