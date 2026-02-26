# Quick Start: Codespace On-Demand Worker

## 🚀 Setup (One-Time)

### 1. Get Cloudflare Tunnel Token

Visit: https://one.dash.cloudflare.com/

1. Navigate to **Networks** → **Tunnels**
2. Click **Create a tunnel**
3. Name: `oz-warp-codespace`
4. **Copy the token** (starts with `eyJ...`)
5. Configure public hostname:
   - Hostname: `oz-warp.aknibir.systems`
   - Service: `http://localhost:8080`
   - Save

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

Set these values:
```bash
WARP_API_KEY=wk-1.YOUR_KEY_HERE
WORKER_ID=codespace-oz-warp
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYOUR_TOKEN_HERE
```

### 3. Make Scripts Executable

```bash
chmod +x codespace-start.sh
```

## 🎯 Daily Usage

### Start Worker (in Codespace)

```bash
./codespace-start.sh
```

This will:
- ✅ Start Cloudflare Tunnel → `oz-warp.aknibir.systems`
- ✅ Start oz-agent-worker → connects to Warp
- ✅ Ready to handle cloud agent tasks

### Use from Local Warp Terminal

Your Warp cloud agents will now run on this worker automatically!

Just use Warp as normal in your local terminal. Tasks will execute in Docker containers in this Codespace.

### Stop Worker

Press `Ctrl+C` in the Codespace terminal

### Stop Codespace (to save money)

- Close the Codespace browser tab, or
- Run: `gh codespace stop` from local terminal

## 💡 How It Works

```
Local Warp Terminal
        ↓
   Warp Server (oz.warp.dev)
        ↓
   Cloudflare Tunnel (oz-warp.aknibir.systems)
        ↓
   GitHub Codespace (this machine)
        ↓
   oz-agent-worker
        ↓
   Docker containers (agent tasks run here)
```

## 📊 Monitor

```bash
# View worker logs (real-time)
./codespace-start.sh

# View tunnel logs
tail -f /tmp/cloudflared.log

# Monitor Docker containers
docker ps
docker stats
```

## 💰 Cost

GitHub Codespaces charges only when **running**:
- 2-core: ~$0.18/hour
- 4-core: ~$0.36/hour

**Tip:** Stop the Codespace when not using cloud agents!

## 🔧 Troubleshooting

### Tunnel not connecting

```bash
# Test manually
cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN"
```

### Worker not starting

```bash
# Check Docker
docker ps

# Check API key
echo $WARP_API_KEY

# Rebuild
go build -o oz-agent-worker .
```

### Can't connect from local Warp

1. Check tunnel status in Cloudflare Dashboard
2. Verify `oz-warp.aknibir.systems` DNS is configured
3. Test: `curl https://oz-warp.aknibir.systems`

## 📚 Full Documentation

- [Complete Codespace Setup](CODESPACE-SETUP.md)
- [Cloudflare Configuration](cloudflare-tunnel-config.yml)
- [Full Deployment Guide](DEPLOYMENT.md)
