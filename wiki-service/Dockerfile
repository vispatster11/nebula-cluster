# Use Python 3.13 slim image as base
FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Install system dependencies (gcc for asyncpg, curl for health checks)
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev curl \
 && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies (no cache to reduce layer size)
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .
COPY database.py .
COPY models.py .
COPY schemas.py .
COPY metrics.py .

# Create a non-root user for security (uid 1000)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup --uid 1000 appuser \
 && chown -R appuser:appgroup /app

# Expose port 8000
EXPOSE 8000

# Health check for Kubernetes and Docker orchestration
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1

# Run as non-root user
USER 1000

# Start FastAPI application with uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
