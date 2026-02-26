# On-Demand Codespace Setup with Cloudflare Tunnel

## Architecture Overview

This setup runs oz-agent-worker in a GitHub Codespace that:
- Starts **on-demand** when you need to use cloud agents
- Connects to your **local Warp terminal** via Cloudflare Tunnel
- Uses your domain **oz-warp.aknibir.systems** managed in Cloudflare
- Stops when you're done (pay-per-use Codespace billing)

```
┌─────────────────┐         Cloudflare Tunnel         ┌──────────────────────┐
│  Local Machine  │ ←──────────────────────────────→ │  GitHub Codespace    │
│  Warp Terminal  │   oz-warp.aknibir.systems         │  oz-agent-worker     │
└─────────────────┘                                    └──────────────────────┘
                                                              │
                                                              ↓
                                                       Docker containers
                                                       (agent tasks)
```

## Prerequisites

1. **Cloudflare Account** with domain `oz-warp.aknibir.systems`
2. **GitHub Codespace** (this current environment)
3. **Local Warp Terminal** on your machine
4. **Cloudflare Tunnel** token or credentials

## Setup Instructions

### Step 1: Create Cloudflare Tunnel

**Option A: Using Cloudflare Dashboard (Recommended for Codespaces)**

1. Go to Cloudflare Zero Trust Dashboard:
   - https://one.dash.cloudflare.com/
   - Navigate to **Networks** → **Tunnels**

2. Click **Create a tunnel**
   - Name: `oz-warp-codespace`
   - Save the tunnel

3. **Copy the tunnel token** (starts with `eyJ...`)
   - You'll need this to run cloudflared in the Codespace

4. **Configure Public Hostnames**:
   - **Public hostname**: `oz-warp.aknibir.systems`
   - **Service**: `https://localhost:8080` (or the port your service uses)
   - **Save**

   - **Public hostname**: `ssh.oz-warp.aknibir.systems` (optional for SSH)
   - **Service**: `ssh://localhost:22`
   - **Save**

**Option B: Using CLI (if you want local control)**

```bash
# On your local machine (not Codespace)
cloudflared tunnel login
cloudflared tunnel create oz-warp-codespace

# Note the tunnel ID and credentials file location
cloudflared tunnel route dns oz-warp-codespace oz-warp.aknibir.systems
```

### Step 2: Install cloudflared in Codespace

This Codespace already has it, but to install on a fresh Codespace:

```bash
# Download cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### Step 3: Configure Environment

Create `.env` in this Codespace:

```bash
cp .env.example .env
nano .env
```

Add:

```bash
# Warp Platform API Key
WARP_API_KEY=wk-1.your-key-here

# Worker ID (unique for this Codespace instance)
WORKER_ID=codespace-oz-warp

# Cloudflare Tunnel Token (from Step 1)
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjMTIzLi4uLi4

# Log level
LOG_LEVEL=info
```

### Step 4: Create Codespace Startup Script

Create `/workspaces/oz-agent-worker-cloud/codespace-start.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "Starting oz-agent-worker in Codespace"
echo "=========================================="

# Load environment
if [[ ! -f .env ]]; then
    echo "❌ .env file not found. Copy .env.example and configure it."
    exit 1
fi

export $(grep -v '^#' .env | xargs)

# Start Cloudflare Tunnel in background
echo "Starting Cloudflare Tunnel..."
if [[ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]]; then
    cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" &
    TUNNEL_PID=$!
    echo "✓ Cloudflare Tunnel started (PID: $TUNNEL_PID)"
else
    echo "⚠️  CLOUDFLARE_TUNNEL_TOKEN not set, tunnel not started"
fi

# Wait for tunnel to establish
sleep 3

# Start oz-agent-worker
echo "Starting oz-agent-worker..."
./oz-agent-worker \
    --api-key "$WARP_API_KEY" \
    --worker-id "$WORKER_ID" \
    --log-level "${LOG_LEVEL:-info}"
```

Make it executable:
```bash
chmod +x codespace-start.sh
```

### Step 5: Run the Worker

**In your Codespace terminal:**

```bash
# Build the worker
go build -o oz-agent-worker .

# Start everything
./codespace-start.sh
```

**The worker will:**
1. Start the Cloudflare Tunnel (makes Codespace accessible via your domain)
2. Start oz-agent-worker (connects to Warp and waits for tasks)
3. Run until you stop it (Ctrl+C)

### Step 6: Access from Local Warp Terminal

From your local machine, you can now:

```bash
# Access the Codespace via your domain
curl https://oz-warp.aknibir.systems

# SSH into Codespace (if configured)
ssh codespace@ssh.oz-warp.aknibir.systems

# Use Warp cloud agents (they'll run on this worker)
# The tasks will execute in Docker containers within the Codespace
```

## Codespace Lifecycle

### Starting Work

1. Open this Codespace (VM starts)
2. Run `./codespace-start.sh` (tunnel + worker start)
3. Use Warp cloud agents from your local terminal

### Stopping Work

1. `Ctrl+C` to stop the worker
2. Stop or close the Codespace (VM stops, billing stops)

### Automatic Startup (Optional)

Add to `.devcontainer/devcontainer.json`:

```json
{
  "postStartCommand": "cd /workspaces/oz-agent-worker-cloud && ./codespace-start.sh &"
}
```

## Docker Considerations in Codespaces

GitHub Codespaces provides Docker-in-Docker. The worker will:

1. Use the Codespace's Docker daemon
2. Spawn task containers inside the Codespace
3. Each container gets isolated filesystem and networking

**Important:**
- Codespace resources are limited (2-32 cores, 4-64GB RAM depending on plan)
- Task containers share these resources
- Monitor usage: `docker stats`

## Environment Variables Summary

```bash
# Required
WARP_API_KEY=wk-1.xxx                          # Your Warp platform key
WORKER_ID=codespace-oz-warp                    # Unique worker ID
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjMTIz...   # Tunnel token from Cloudflare

# Optional
LOG_LEVEL=info                                 # debug|info|warn|error
GITHUB_TOKEN=ghp_xxx                           # For pulling from GHCR (if needed)
```

## Troubleshooting

### Tunnel Not Connecting

```bash
# Test tunnel manually
cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN"

# Check logs
cloudflared tunnel info
```

### Worker Can't Reach Docker

```bash
# Codespaces should have Docker pre-configured
docker ps

# If not, start Docker
sudo systemctl start docker
```

### Worker Can't Connect to Warp

```bash
# Test connectivity
curl -I https://oz.warp.dev

# Check API key
echo $WARP_API_KEY

# Verify it starts with "wk-"
```

### Codespace Stops Unexpectedly

- Codespaces auto-stop after idle timeout (default: 30 minutes)
- Change timeout: Go to GitHub → Settings → Codespaces → Default idle timeout
- Or keep it active with periodic activity

## Cost Optimization

**GitHub Codespaces Billing:**
- Only charged when Codespace is **running** (not stopped)
- 2-core machine: ~$0.18/hour
- 4-core machine: ~$0.36/hour

**Tips:**
1. Stop Codespace when not using cloud agents
2. Use smaller machine if tasks are light
3. Set aggressive idle timeout
4. Monitor usage: https://github.com/settings/billing

## Security Notes

1. **Never commit** `.env` with real keys
2. **Cloudflare Tunnel** provides secure access without exposing Codespace ports
3. **Worker authentication** uses WARP_API_KEY (scoped to your team)
4. **Docker socket** is isolated to the Codespace VM

## Alternative: Docker Compose for Codespaces

Create `docker-compose.codespace.yml`:

```yaml
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    network_mode: host

  oz-agent-worker:
    build: .
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      WARP_API_KEY: ${WARP_API_KEY}
    command: --worker-id ${WORKER_ID}
```

Run with:
```bash
docker-compose -f docker-compose.codespace.yml up
```

## Next Steps

1. Get Cloudflare Tunnel token from dashboard
2. Configure `.env` with all required variables
3. Run `./codespace-start.sh`
4. Test from your local Warp terminal
5. Stop Codespace when done to save costs
