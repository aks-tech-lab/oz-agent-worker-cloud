# GitHub Container Registry (GHCR) Configuration

## Environment Variables for GHCR Authentication

For pushing/pulling images to `ghcr.io/aks-tech-lab/oz-warp.aknibir.systems`, you need:

### Required Variables

```bash
# GitHub Personal Access Token or GITHUB_TOKEN
# Scopes needed: write:packages, read:packages, delete:packages (optional)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Your GitHub username
GITHUB_USERNAME=aks-tech-lab

# Registry URL (always the same for GHCR)
CONTAINER_REGISTRY=ghcr.io

# Full image name
IMAGE_NAME=ghcr.io/aks-tech-lab/oz-warp.aknibir.systems
```

### How to Get a GitHub Token

1. Go to https://github.com/settings/tokens/new
2. Select scopes:
   - `write:packages` - Upload packages
   - `read:packages` - Download packages
   - `delete:packages` - Delete package versions (optional)
3. Generate and copy the token (starts with `ghp_`)

### Login to GHCR

```bash
# Login using environment variable
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Or login interactively
docker login ghcr.io -u aks-tech-lab
# Password: [paste your token]
```

### Using in GitHub Actions

GitHub Actions has built-in `GITHUB_TOKEN` with automatic GHCR access:

```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

## Docker Daemon Configuration (Separate from GHCR)

These variables configure how the **oz-agent-worker connects to the Docker daemon** to spawn task containers. They do NOT affect GHCR authentication:

```bash
# ============================================================================
# Docker Daemon Connection Settings
# ============================================================================
# These control where the worker finds the Docker daemon to run containers

# Docker daemon address
DOCKER_HOST=unix:///var/run/docker.sock
# Examples:
# - unix:///var/run/docker.sock       (local socket - default)
# - tcp://remote-host:2376            (remote daemon via TCP)
# - tcp://localhost:2375              (local TCP without TLS)

# Docker API version (optional - auto-negotiated by default)
DOCKER_API_VERSION=1.41

# TLS settings for remote Docker daemon
DOCKER_TLS_VERIFY=1                    # Enable TLS verification
DOCKER_CERT_PATH=/path/to/certs        # Path to client certificates

# Docker context (alternative to DOCKER_HOST)
DOCKER_CONTEXT=my-remote-context       # Use named context from ~/.docker/config.json
```

## Summary: Two Separate Concerns

| Purpose | Environment Variables | Used By |
|---------|----------------------|---------|
| **Push/Pull from GHCR** | `GITHUB_TOKEN`, `GITHUB_USERNAME` | Docker CLI (`docker push/pull`) |
| **Connect to Docker Daemon** | `DOCKER_HOST`, `DOCKER_TLS_VERIFY`, etc. | oz-agent-worker (to spawn containers) |

## Complete .env Example for GHCR Deployment

```bash
# =============================================================================
# oz-agent-worker with GHCR
# =============================================================================

# ------------------------------------------------------------------------------
# Warp Platform (Required)
# ------------------------------------------------------------------------------
WARP_API_KEY=wk-1.your-actual-key-here
WORKER_ID=oz-warp-prod

# ------------------------------------------------------------------------------
# GHCR Authentication (For pulling the worker image)
# ------------------------------------------------------------------------------
GITHUB_TOKEN=ghp_your-github-token-here
GITHUB_USERNAME=aks-tech-lab
CONTAINER_REGISTRY=ghcr.io
IMAGE_NAME=ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest

# ------------------------------------------------------------------------------
# Docker Daemon Connection (Where to run task containers)
# ------------------------------------------------------------------------------
DOCKER_HOST=unix:///var/run/docker.sock
# DOCKER_API_VERSION=1.41
# DOCKER_TLS_VERIFY=1
# DOCKER_CERT_PATH=/path/to/certs
# DOCKER_CONTEXT=my-context

# ------------------------------------------------------------------------------
# Worker Settings (Optional)
# ------------------------------------------------------------------------------
LOG_LEVEL=info
```

## Testing GHCR Access

```bash
# 1. Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# 2. Pull the image
docker pull ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest

# 3. Verify
docker images | grep oz-warp

# 4. Run the worker
docker run -d \
  --name oz-agent-worker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WARP_API_KEY="$WARP_API_KEY" \
  ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest \
  --worker-id "oz-warp-prod"
```

## Troubleshooting

### Error: "denied: permission_denied"

Your token lacks `write:packages` or `read:packages` scope.
- Create new token at: https://github.com/settings/tokens/new
- Select the `write:packages` scope

### Error: "unauthorized: authentication required"

Not logged in to GHCR:
```bash
docker login ghcr.io -u aks-tech-lab
```

### Error: "Error response from daemon: Get https://ghcr.io/v2/..."

Network connectivity issue:
```bash
# Test GHCR connectivity
curl -I https://ghcr.io/v2/

# Check DNS
nslookup ghcr.io
```

## Repository Visibility

GHCR packages can be private or public:

1. Go to: https://github.com/orgs/aks-tech-lab/packages
2. Find: `oz-warp.aknibir.systems`
3. Settings → Change visibility to **Public** (no auth needed for pull) or keep **Private** (requires token)
