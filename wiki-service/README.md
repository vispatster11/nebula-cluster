# Wiki API Service

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
