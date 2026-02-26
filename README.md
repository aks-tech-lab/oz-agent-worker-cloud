# oz-agent-worker

Self-hosted worker for Oz cloud agents.

📖 **[Documentation](https://docs.warp.dev/agent-platform/cloud-agents/self-hosting)**

## Overview

`oz-agent-worker` is a daemon that connects to Oz via WebSocket to receive and execute cloud agent tasks on self-hosted infrastructure.

**🚀 Running in GitHub Codespaces?** → See [QUICKSTART-CODESPACE.md](QUICKSTART-CODESPACE.md)

## Quick Start

### Option 1: GitHub Codespace (On-Demand)

Perfect for development or occasional use. Only pay when running.

```bash
# 1. Configure (one-time)
cp .env.example .env
# Edit .env: set WARP_API_KEY, WORKER_ID, CLOUDFLARE_TUNNEL_TOKEN

# 2. Start worker
./codespace-start.sh

# 3. Use from your local Warp terminal
# Tasks run in this Codespace via oz-warp.aknibir.systems
```

📖 **[Full Codespace Guide](QUICKSTART-CODESPACE.md)**

### Option 2: Traditional Server (Always-On)

For production or high-volume use.

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env and set WARP_API_KEY and WORKER_ID

# 2. Login to GHCR (if using the Docker image)
./ghcr-login.sh  # Interactive setup
# OR manually:
# echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 3. Run with Docker Compose (easiest)
docker-compose up -d

# OR run the quick start script
chmod +x start.sh
./start.sh
```

📦 **[Full Deployment Guide](DEPLOYMENT.md)** | 🔑 **[GHCR Configuration](GHCR-CONFIG.md)** | 🚀 **[DEPLOY Branch Workflow](.github/workflows/deploy.yml)**

## Requirements

- Docker daemon (accessible via socket or TCP)
- Service account API key with team scope
- Network egress to warp-server

## Usage

### Docker (Recommended)

The worker needs access to the Docker daemon to spawn task containers. Mount the host's Docker socket into the container:

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock \
  -e WARP_API_KEY="wk-abc123" \
  warpdotdev/oz-agent-worker --worker-id "my-worker"
```

> **Note:** Mounting the Docker socket gives the container access to the host's Docker daemon. This is required for the worker to create and manage task containers.

### Go Install

```bash
go install github.com/warpdotdev/oz-agent-worker@latest
oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker"
```

### Build from Source

```bash
git clone https://github.com/warpdotdev/oz-agent-worker.git
cd oz-agent-worker
go build -o oz-agent-worker
./oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker"
```

## Environment Variables for Task Containers

Use `-e` / `--env` to pass environment variables into task containers:

```bash
# Explicit key=value
oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker" -e MY_SECRET=hunter2

# Pass through from host environment
export MY_SECRET=hunter2
oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker" -e MY_SECRET

# Multiple variables
oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker" -e FOO=bar -e BAZ=qux
```

When using Docker to run the worker, note that `-e` flags for the worker itself (task containers) are passed as arguments, while `-e` flags for the worker container use Docker's syntax:

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock \
  -e WARP_API_KEY="wk-abc123" \
  warpdotdev/oz-agent-worker --worker-id "my-worker" -e MY_SECRET=hunter2
```

## Docker Connectivity

The worker automatically discovers the Docker daemon using standard Docker client mechanisms, in this order:

1. **`DOCKER_HOST`** environment variable (e.g., `unix:///var/run/docker.sock`, `tcp://localhost:2375`)
2. **Default socket location** (`/var/run/docker.sock` on Linux, `~/.docker/run/docker.sock` for rootless)
3. **Docker context** via `DOCKER_CONTEXT` environment variable
4. **Config file** (`~/.docker/config.json`) for context settings

Additional supported environment variables:
- `DOCKER_API_VERSION` - Specify Docker API version
- `DOCKER_CERT_PATH` - Path to TLS certificates
- `DOCKER_TLS_VERIFY` - Enable TLS verification

### Example: Remote Docker Daemon

```bash
export DOCKER_HOST="tcp://remote-host:2376"
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/path/to/certs"
oz-agent-worker --api-key "wk-abc123" --worker-id "my-worker"
```

## License

Copyright © 2026 Warp
