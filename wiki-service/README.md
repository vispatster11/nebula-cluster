# Wiki API Service
A lightweight FastAPI application that manages users and posts with real-time Prometheus metrics and PostgreSQL persistence.

## What This Does

The Wiki Service exposes a REST API for:

- Creating and managing users (`/users` endpoints)
- Publishing and retrieving posts (`/posts` endpoints)
- Monitoring metrics via Prometheus (`/metrics` endpoint)

It uses PostgreSQL as the database backend and is designed to run in Kubernetes via the Helm chart in `../wiki-chart/`.

## Local Development

### Prerequisites

- Python 3.13
- PostgreSQL 15 (or Docker)
- pip or Poetry

### Quick Start

1. **Install dependencies:**

```bash
pip install -r requirements.txt
```

2. **Start PostgreSQL** (using Docker):

```bash
docker run \
	-e POSTGRES_USER=postgres \
	-e POSTGRES_PASSWORD=postgres \
	-e POSTGRES_DB=wiki \
	-p 5432:5432 \
	postgres:15-alpine
```

Wait a few seconds for Postgres to be ready, then:

3. **Run the application:**

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API is now available at `http://localhost:8000`. You should see the API documentation at `http://localhost:8000/docs`.

### Testing

Create a user:

```bash
curl -X POST http://localhost:8000/users \
	-H "Content-Type: application/json" \
	-d '{"name": "Alice", "email": "alice@example.com"}'
```

Create a post:

```bash
curl -X POST http://localhost:8000/posts \
	-H "Content-Type: application/json" \
	-d '{"user_id": 1, "title": "My First Post", "content": "Hello, World!"}'
```

View metrics:

```bash
curl http://localhost:8000/metrics
```

## Building the Docker Image

From the repository root:

```bash
docker build -t wiki-service:0.1.0 wiki-service/
```

The Dockerfile uses a multi-stage build for efficiency and runs as a non-root user for security.

## Configuration via Environment Variables

The service reads database configuration from environment variables:

| Variable   | Default     | Purpose                         |
|------------|-------------|--------------------------------|
| `DB_USER`     | `postgres`  | PostgreSQL username             |
| `DB_PASSWORD` | `postgres`  | PostgreSQL password             |
| `DB_HOST`     | `localhost` | PostgreSQL host (or service name in k8s) |
| `DB_PORT`     | `5432`      | PostgreSQL port                 |
| `DB_NAME`     | `wiki`      | Database name to use            |

In Kubernetes, these are set via the Helm chart's `values.yaml` and injected as environment variables into the FastAPI pod.

## API Reference

### Users

- `POST /users` — Create a new user
- `GET /users` — List all users
- `GET /user/{id}` — Get a specific user by ID

### Posts

- `POST /posts` — Create a new post (requires `user_id`)
- `GET /posts/{id}` — Get a specific post by ID

### Monitoring

- `GET /metrics` — Prometheus metrics (counters for users created, posts created)
- `GET /` — API info endpoint

Interactive API documentation is available at `/docs` (Swagger UI) and `/redoc` (ReDoc).

## Architecture

**FastAPI Server**: Handles HTTP requests and responses

**SQLAlchemy + asyncpg**: Async ORM for database operations (uses asyncpg driver for efficient async Postgres connections)

**Prometheus Client**: Exposes metrics counters for tracking user and post creation rates

**Uvicorn**: ASGI server for running the FastAPI application

## Kubernetes Deployment

For Kubernetes deployment, use the Helm chart in the `../wiki-chart/` directory. The chart handles:

- Deploying FastAPI with the correct image
- Managing PostgreSQL as a StatefulSet
- Setting up Prometheus scraping
- Configuring Grafana dashboards
- Creating Ingress for external access

See `../PIPELINE.md` for deployment instructions.

FastAPI-based Wikipedia-like service for managing users and posts.

## Features

- Create and retrieve users
- Create and retrieve posts  
- Async database operations with SQLAlchemy
- PostgreSQL database integration
- Prometheus metrics for monitoring

## Building the Docker Image

```bash
docker build -t wiki-fastapi:0.1.0 .
```

## Environment Variables

The service uses the following environment variables:

- `DB_USER`: PostgreSQL username (default: `postgres`)
- `DB_PASSWORD`: PostgreSQL password (default: `postgres`)
- `DB_HOST`: PostgreSQL host (default: `localhost`)
- `DB_PORT`: PostgreSQL port (default: `5432`)
- `DB_NAME`: Database name (default: `wiki`)

## Running Locally

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Start PostgreSQL (or use Docker):
```bash
docker run -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=wiki -p 5432:5432 postgres:15-alpine
```

3. Run the application:
```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`

## API Endpoints

- `POST /users` - Create a new user
- `GET /user/{id}` - Get user by ID
- `POST /posts` - Create a new post
- `GET /posts/{id}` - Get post by ID
- `GET /metrics` - Prometheus metrics

## Deployment

For Kubernetes deployment, use the Helm chart in the `wiki-chart/` directory.
