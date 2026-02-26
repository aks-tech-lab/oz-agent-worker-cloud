#!/bin/bash
# Codespace startup script for oz-agent-worker with Cloudflare Tunnel
set -euo pipefail

echo "=========================================="
echo "oz-agent-worker Codespace Startup"
echo "=========================================="
echo

# Load environment variables
if [[ ! -f .env ]]; then
    echo "❌ .env file not found"
    echo "   Run: cp .env.example .env"
    echo "   Then edit .env with your credentials"
    exit 1
fi

echo "Loading environment from .env..."
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Validate required variables
MISSING_VARS=()
[[ -z "${WARP_API_KEY:-}" || "$WARP_API_KEY" == "wk-" ]] && MISSING_VARS+=("WARP_API_KEY")
[[ -z "${WORKER_ID:-}" || "$WORKER_ID" == "my-worker" ]] && MISSING_VARS+=("WORKER_ID")

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo "❌ Missing required variables in .env:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

if [[ "$WORKER_ID" == warp* ]]; then
    echo "❌ WORKER_ID cannot start with 'warp' (reserved prefix)"
    exit 1
fi

echo "✓ Environment configured"
echo "  WORKER_ID: $WORKER_ID"
echo "  LOG_LEVEL: ${LOG_LEVEL:-info}"
echo

# Check Docker
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Cannot access Docker daemon"
    echo "   Codespaces should have Docker pre-installed"
    echo "   Try: sudo systemctl start docker"
    exit 1
fi
echo "✓ Docker daemon accessible"
echo

# Start Cloudflare Tunnel if token provided
if [[ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" && "$CLOUDFLARE_TUNNEL_TOKEN" != "your-token-here" ]]; then
    echo "Starting Cloudflare Tunnel..."
    
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo "Installing cloudflared..."
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /tmp/cloudflared
        chmod +x /tmp/cloudflared
        sudo mv /tmp/cloudflared /usr/local/bin/cloudflared
    fi
    
    # Start tunnel in background
    cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" > /tmp/cloudflared.log 2>&1 &
    TUNNEL_PID=$!
    
    # Save PID for cleanup
    echo $TUNNEL_PID > /tmp/cloudflared.pid
    
    echo "✓ Cloudflare Tunnel started (PID: $TUNNEL_PID)"
    echo "  Domain: oz-warp.aknibir.systems"
    echo "  Logs: tail -f /tmp/cloudflared.log"
    
    # Wait for tunnel to establish
    sleep 3
else
    echo "⚠️  CLOUDFLARE_TUNNEL_TOKEN not set"
    echo "   Worker will run but won't be accessible via domain"
    echo "   Get token at: https://one.dash.cloudflare.com/"
fi

echo

# Build the worker if not already built
if [[ ! -f oz-agent-worker ]]; then
    echo "Building oz-agent-worker..."
    if command -v go >/dev/null 2>&1; then
        go build -o oz-agent-worker .
        echo "✓ Build complete"
    else
        echo "❌ Go not installed, cannot build"
        exit 1
    fi
    echo
fi

# Trap to cleanup on exit
cleanup() {
    echo
    echo "Shutting down..."
    
    # Stop Cloudflare Tunnel
    if [[ -f /tmp/cloudflared.pid ]]; then
        TUNNEL_PID=$(cat /tmp/cloudflared.pid)
        if kill -0 "$TUNNEL_PID" 2>/dev/null; then
            echo "Stopping Cloudflare Tunnel (PID: $TUNNEL_PID)..."
            kill "$TUNNEL_PID" 2>/dev/null || true
        fi
        rm -f /tmp/cloudflared.pid
    fi
    
    echo "✓ Cleanup complete"
}

trap cleanup EXIT INT TERM

# Start oz-agent-worker
echo "=========================================="
echo "Starting oz-agent-worker..."
echo "=========================================="
echo "Press Ctrl+C to stop"
echo

./oz-agent-worker \
    --api-key "$WARP_API_KEY" \
    --worker-id "$WORKER_ID" \
    --log-level "${LOG_LEVEL:-info}"
