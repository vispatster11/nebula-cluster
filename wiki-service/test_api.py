"""
Basic API tests for wiki-service FastAPI application.
Tests core endpoints with PostgreSQL backend.
"""

import pytest
import pytest_asyncio
import os
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

# Override database URL for tests
os.environ["DB_USER"] = os.getenv("DB_USER", "postgres")
os.environ["DB_PASSWORD"] = os.getenv("DB_PASSWORD", "postgres")
os.environ["DB_HOST"] = os.getenv("DB_HOST", "127.0.0.1")
os.environ["DB_PORT"] = os.getenv("DB_PORT", "5432")
os.environ["DB_NAME"] = os.getenv("DB_NAME", "wiki")

from main import app
from database import Base, get_db


@pytest_asyncio.fixture
async def test_db():
    """Create test database and tables."""
    db_user = os.getenv("DB_USER", "postgres")
    db_password = os.getenv("DB_PASSWORD", "postgres")
    db_host = os.getenv("DB_HOST", "127.0.0.1")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "wiki")
    
    DATABASE_URL = f"postgresql+asyncpg://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
    
    engine = create_async_engine(DATABASE_URL, echo=False, future=True)
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    
    AsyncSessionLocal = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async def override_get_db():
        async with AsyncSessionLocal() as session:
            yield session
    
    app.dependency_overrides[get_db] = override_get_db
    
    yield engine
    
    await engine.dispose()


@pytest_asyncio.fixture
async def async_client(test_db):
    """Create async HTTP client for testing."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.mark.asyncio
async def test_root_endpoint(async_client):
    """Test root endpoint returns API info."""
    response = await async_client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "endpoints" in data


@pytest.mark.asyncio
async def test_create_user(async_client):
    """Test user creation endpoint."""
    response = await async_client.post("/users", json={"name": "Test User"})
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test User"
    assert "id" in data
    assert "created_time" in data


@pytest.mark.asyncio
async def test_get_user(async_client):
    """Test retrieving a user by ID."""
    # Create user first
    create_response = await async_client.post("/users", json={"name": "Get Test"})
    user_id = create_response.json()["id"]
    
    # Get user
    response = await async_client.get(f"/user/{user_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == user_id
    assert data["name"] == "Get Test"


@pytest.mark.asyncio
async def test_create_post(async_client):
    """Test post creation endpoint."""
    # Create user first
    user_response = await async_client.post("/users", json={"name": "Post Author"})
    user_id = user_response.json()["id"]
    
    # Create post
    response = await async_client.post(
        "/posts",
        json={"user_id": user_id, "content": "Test post content"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == user_id
    assert data["content"] == "Test post content"
    assert "post_id" in data
    assert "created_time" in data


@pytest.mark.asyncio
async def test_get_post(async_client):
    """Test retrieving a post by ID."""
    # Create user and post
    user_response = await async_client.post("/users", json={"name": "Post Retriever"})
    user_id = user_response.json()["id"]
    
    post_response = await async_client.post(
        "/posts",
        json={"user_id": user_id, "content": "Content to retrieve"}
    )
    post_id = post_response.json()["post_id"]
    
    # Get post
    response = await async_client.get(f"/posts/{post_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["post_id"] == post_id
    assert data["content"] == "Content to retrieve"


@pytest.mark.asyncio
async def test_metrics_endpoint(async_client):
    """Test Prometheus metrics endpoint."""
    response = await async_client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    # Should contain counter metrics
    assert b"users_created_total" in response.content or b"posts_created_total" in response.content
