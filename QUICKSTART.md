# Quick Start for Test Grader

## TL;DR

```bash
# Build (30-60 seconds)
docker build -t nebula-cluster .

# Run (90-120 seconds startup)
docker run --privileged -p 8080:8080 nebula-cluster

# Wait for "Container ready" message, then test:
curl http://localhost:8080/users
curl -X POST http://localhost:8080/users -H "Content-Type: application/json" -d '{"name":"Test"}'
curl http://localhost:8080/grafana/d/creation-dashboard-678/creation
```

**All services available at `http://localhost:8080`**

---

## Verification

### API is Ready When:
- Docker logs show: **"Container ready. Use Ctrl+C to stop."**
- `curl http://localhost:8080/` returns JSON response
- Timing: ~90-120 seconds after `docker run`

### Test These Endpoints

```bash
# Health check
curl http://localhost:8080/

# Create user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'

# Get user
curl http://localhost:8080/users/1

# Create post
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{"content": "Hello World", "user_id": 1}'

# Get post
curl http://localhost:8080/posts/1

# Metrics
curl http://localhost:8080/metrics | head -20

# Grafana Dashboard
open http://localhost:8080/grafana/d/creation-dashboard-678/creation
# Login: admin / admin
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Build fails** | Ensure Docker daemon is running; 30GB free space for build layers |
| **Run fails: "privileged"** | Add `--privileged` flag (required for Docker-in-Docker) |
| **Services not ready** | Wait ~120s; check with `docker logs <id>` |
| **Port 8080 in use** | Use alternate port: `docker run --privileged -p 9090:8080 nebula-cluster` |
| **Can't access Grafana** | Dashboard is at `/grafana/d/creation-dashboard-678/creation` (exact path) |

---

## What's Running

- **FastAPI** @ `http://localhost:8080/`
- **PostgreSQL** @ `localhost:5432` (inside cluster only)
- **Prometheus** @ `http://localhost:8080/prometheus` (internal)
- **Grafana** @ `http://localhost:8080/grafana/`

---

## Container Lifecycle

```bash
# Stop (pause container)
docker stop <container-id>

# Start (resume)
docker start <container-id>

# Remove (delete - data lost)
docker rm <container-id>

# View logs
docker logs -f <container-id>

# Access shell
docker exec -it <container-id> sh
```

---

## Requirements

- **Docker:** 20.10+
- **RAM:** 4GB minimum (6GB recommended)
- **Disk:** 5GB free
- **CPU:** 2+ cores
- **Privileged mode:** Required (`--privileged` flag)

---

## Performance Expectations

| Phase | Duration |
|-------|----------|
| Docker build | 30-60s |
| Container startup | ~10s |
| Cluster creation | ~30s |
| Image build (wiki-service) | ~20s |
| Pod initialization | ~20-30s |
| **Total** | ~90-120s |

---

## FAQ

**Q: Do I need to change anything?**
A: No. Run the commands as-is.

**Q: How do I know it's working?**
A: When you see "Container ready" in logs, hit `curl http://localhost:8080/`.

**Q: Can I run multiple instances?**
A: Yes, use different ports: `docker run --privileged -p 9090:8080 nebula-cluster`

**Q: What about the database?**
A: PostgreSQL runs inside the cluster, data persists across restarts (same container).

**Q: Is the data persistent?**
A: Yes, within container. Lost if you `docker rm` (not `docker stop`).

**Q: Can I inspect the cluster?**
A: Yes: `docker exec <id> kubectl get pods`, `docker exec <id> kubectl logs <pod>`

**Q: What if something breaks?**
A: See Troubleshooting section in `README.md`.

---

**For complete documentation, see:** `README.md`
