# DEPLOY Branch Setup Guide

This guide covers deploying the oz-agent-worker to production with GHCR and Cloudflare Tunnel.

## Prerequisites

- [x] Git repository with remote access
- [ ] GitHub repository write access for GHCR
- [ ] Cloudflare account with domain `oz-warp.aknibir.systems`
- [ ] Docker installed locally
- [ ] `cloudflared` CLI installed

## Step 1: Create and Push DEPLOY Branch

```bash
cd /workspaces/oz-agent-worker-cloud

# Commit current changes
git add .
git commit -m "Add deployment configuration and Cloudflare tunnel setup"

# Create DEPLOY branch from current branch
git checkout -b DEPLOY

# Push to remote
git push -u origin DEPLOY
```

## Step 2: Build and Push Docker Image to GHCR

### Option A: Using GitHub Actions (Automated)

The push to the DEPLOY branch will automatically trigger the workflow at [.github/workflows/deploy.yml](.github/workflows/deploy.yml) which will:
- Build the Docker image for linux/amd64 and linux/arm64
- Push to `ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest`

GitHub Actions automatically has access to GHCR via `GITHUB_TOKEN`.

### Option B: Manual Build and Push

```bash
# Log in to GHCR with your GitHub token
# Get token at: https://github.com/settings/tokens/new (scope: write:packages)
export GITHUB_TOKEN=ghp_your_token_here
export GITHUB_USERNAME=aks-tech-lab

echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Build multi-platform image
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest \
  --push .
```

**Note:** See [GHCR-CONFIG.md](GHCR-CONFIG.md) for detailed GHCR authentication and troubleshooting.

## Step 3: Configure Cloudflare Tunnel

### 3.1 Install cloudflared

```bash
# Ubuntu/Debian
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### 3.2 Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser to authenticate and download your credentials.

### 3.3 Create Tunnel

```bash
cloudflared tunnel create oz-warp
```

Note the Tunnel ID from the output.

### 3.4 Configure Tunnel

Edit `cloudflare-tunnel-config.yml` and replace `<tunnel-id>` with your actual tunnel ID:

```yaml
tunnel: oz-warp
credentials-file: /root/.cloudflared/<your-tunnel-id>.json

ingress:
  - hostname: oz-warp.aknibir.systems
    service: https://humble-fiesta-g7wv7g5xww5hwjr5.github.dev
    originRequest:
      noTLSVerify: false
  
  - hostname: ssh.oz-warp.aknibir.systems
    service: ssh://localhost:22
  
  - service: http_status:404
```

Copy the configuration:

```bash
sudo mkdir -p /etc/cloudflared
sudo cp cloudflare-tunnel-config.yml /etc/cloudflared/config.yml
```

### 3.5 Create DNS Records

Add DNS records in your Cloudflare dashboard for `oz-warp.aknibir.systems`:

```bash
# Main domain - HTTPS proxy to GitHub Codespace
cloudflared tunnel route dns oz-warp oz-warp.aknibir.systems

# SSH subdomain
cloudflared tunnel route dns oz-warp ssh.oz-warp.aknibir.systems
```

Alternatively, manually create CNAME records:
- `oz-warp.aknibir.systems` → `<tunnel-id>.cfargotunnel.com`
- `ssh.oz-warp.aknibir.systems` → `<tunnel-id>.cfargotunnel.com`

### 3.6 Start Tunnel

```bash
# Test run (foreground)
cloudflared tunnel --config /etc/cloudflared/config.yml run oz-warp

# Install as a system service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
sudo systemctl status cloudflared
```

## Step 4: Environment Variables and Keys

### 4.1 Create .env File

```bash
cp .env.example .env
```

Edit `.env` and set:

```bash
# Required: Your Warp Platform API key
WARP_API_KEY=wk-1.cdbacaf29e038343417eb172d4a683190b5daf252487b9ad9e7027aacd4a8c53

# Required: Unique worker identifier (must NOT start with "warp")
WORKER_ID=oz-warp-prod

# Optional: Docker daemon configuration
DOCKER_HOST=unix:///var/run/docker.sock

# Optional: Logging level
LOG_LEVEL=info
```

**⚠️ Security Warning**: Never commit `.env` to git. It's already in `.gitignore`.

### 4.2 Verify Docker Connectivity

```bash
# Test Docker daemon access
docker ps

# If using remote Docker daemon
export DOCKER_HOST=tcp://remote-host:2376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=/path/to/certs
docker ps
```

### 4.3 Run the Worker

```bash
# Using the binary
./oz-agent-worker --api-key "$WARP_API_KEY" --worker-id "oz-warp-prod"

# Using Docker with GHCR image
docker run -d \
  --name oz-agent-worker \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WARP_API_KEY="$WARP_API_KEY" \
  ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest \
  --worker-id "oz-warp-prod"
```

## Step 5: Verification

### 5.1 Check Worker Status

```bash
# View worker logs
docker logs -f oz-agent-worker

# Expected output:
# INFO  Connecting to wss://oz.warp.dev/api/v1/selfhosted/worker/ws
# INFO  Successfully connected to server
```

### 5.2 Test SSH Access

From your local machine:

```bash
ssh user@ssh.oz-warp.aknibir.systems
# Or if using port 22 on main domain:
ssh user@oz-warp.aknibir.systems -p 22
```

### 5.3 Test HTTPS Proxy

Open in browser: https://oz-warp.aknibir.systems

Should proxy to: https://humble-fiesta-g7wv7g5xww5hwjr5.github.dev/

## Troubleshooting

### Worker Can't Connect to Docker

```bash
# Check Docker daemon
sudo systemctl status docker

# Check socket permissions
ls -l /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock  # For testing only
```

### Cloudflare Tunnel Not Working

```bash
# Check tunnel status
cloudflared tunnel info oz-warp

# View tunnel logs
sudo journalctl -u cloudflared -f

# Test DNS resolution
nslookup oz-warp.aknibir.systems
```

### Worker Can't Reach Warp Server

```bash
# Test WebSocket connectivity
curl -I https://oz.warp.dev

# Check network egress
ping oz.warp.dev
```

## Security Checklist

- [ ] API key stored securely (not committed to git)
- [ ] Docker socket permissions minimized (use Docker context or TCP with TLS)
- [ ] Cloudflare Tunnel credentials protected (`chmod 600`)
- [ ] SSH keys configured (disable password auth)
- [ ] Worker runs as non-root user in production
- [ ] Container images are verified and up-to-date
- [ ] Network policies restrict unnecessary egress

## Monitoring

```bash
# Worker container stats
docker stats oz-agent-worker

# Worker logs with filtering
docker logs oz-agent-worker 2>&1 | grep ERROR

# Cloudflare tunnel analytics
# Visit: https://dash.cloudflare.com → Zero Trust → Access → Tunnels
```
