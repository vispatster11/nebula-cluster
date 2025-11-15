# Multi-stage build: Final stage is Docker-in-Docker with k3d cluster
FROM docker:27.3.1-dind

# Install required tools
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    jq \
    kubectl \
    helm \
    && echo "Tools installed"

# Install k3d (v5.8.3 for k3s v1.31.5)
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Copy application and chart files
WORKDIR /app
COPY wiki-service/ ./wiki-service/
COPY wiki-chart/ ./wiki-chart/
COPY entrypoint.sh ./
RUN chmod +x ./entrypoint.sh

# Expose port 8080 (maps to k3d LoadBalancer port 80)
EXPOSE 8080

# Run the entrypoint script
ENTRYPOINT ["./entrypoint.sh"]
