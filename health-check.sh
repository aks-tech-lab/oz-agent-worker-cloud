#!/bin/bash
# Health check script for oz-agent-worker Codespace

set -euo pipefail

echo "=========================================="
echo "oz-agent-worker Health Check"
echo "=========================================="
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Environment file
echo "1. Environment Configuration"
if [[ -f .env ]]; then
    check_pass ".env file exists"
    
    if grep -q "^WARP_API_KEY=wk-" .env && ! grep -q "^WARP_API_KEY=wk-$" .env; then
        check_pass "WARP_API_KEY is set"
    else
        check_fail "WARP_API_KEY not configured"
    fi
    
    if grep -q "^WORKER_ID=" .env && ! grep -q "^WORKER_ID=my-worker" .env; then
        check_pass "WORKER_ID is set"
    else
        check_fail "WORKER_ID not configured"
    fi
    
    if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" .env && ! grep -q "^CLOUDFLARE_TUNNEL_TOKEN=$" .env; then
        check_pass "CLOUDFLARE_TUNNEL_TOKEN is set"
    else
        check_warn "CLOUDFLARE_TUNNEL_TOKEN not set (tunnel won't work)"
    fi
else
    check_fail ".env file not found (copy from .env.example)"
fi
echo

# Check 2: Docker
echo "2. Docker Daemon"
if docker ps >/dev/null 2>&1; then
    check_pass "Docker daemon is accessible"
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    echo "   Running containers: $CONTAINER_COUNT"
else
    check_fail "Docker daemon not accessible"
fi
echo

# Check 3: Binary
echo "3. Worker Binary"
if [[ -f oz-agent-worker ]]; then
    check_pass "oz-agent-worker binary exists"
    SIZE=$(ls -lh oz-agent-worker | awk '{print $5}')
    echo "   Size: $SIZE"
else
    check_warn "oz-agent-worker binary not built (run: go build -o oz-agent-worker .)"
fi
echo

# Check 4: Cloudflare Tunnel
echo "4. Cloudflare Tunnel"
if command -v cloudflared >/dev/null 2>&1; then
    check_pass "cloudflared is installed"
    VERSION=$(cloudflared --version 2>&1 | head -n1)
    echo "   $VERSION"
    
    if [[ -f /tmp/cloudflared.pid ]]; then
        PID=$(cat /tmp/cloudflared.pid)
        if kill -0 "$PID" 2>/dev/null; then
            check_pass "Tunnel is running (PID: $PID)"
        else
            check_warn "Tunnel PID file exists but process is not running"
        fi
    else
        check_warn "Tunnel is not running"
    fi
else
    check_warn "cloudflared not installed"
fi
echo

# Check 5: Network connectivity
echo "5. Network Connectivity"
if curl -s -I https://oz.warp.dev -m 5 >/dev/null; then
    check_pass "Can reach oz.warp.dev"
else
    check_fail "Cannot reach oz.warp.dev (check network)"
fi

if [[ -f .env ]] && grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" .env; then
    if curl -s -I https://oz-warp.aknibir.systems -m 5 >/dev/null 2>&1; then
        check_pass "Domain oz-warp.aknibir.systems is reachable"
    else
        check_warn "Domain oz-warp.aknibir.systems not reachable (tunnel may not be configured)"
    fi
fi
echo

# Check 6: Process status
echo "6. Worker Process"
if pgrep -f "oz-agent-worker" >/dev/null; then
    PID=$(pgrep -f "oz-agent-worker")
    check_pass "Worker is running (PID: $PID)"
    
    # Show memory usage
    MEM=$(ps -p "$PID" -o rss= 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
    echo "   Memory: $MEM"
else
    check_warn "Worker is not running"
fi
echo

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="

if [[ -f .env ]] && docker ps >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Ready to start${NC}"
    echo
    echo "Start with: ./codespace-start.sh"
else
    echo -e "${RED}✗ Configuration incomplete${NC}"
    echo
    echo "Next steps:"
    echo "1. cp .env.example .env"
    echo "2. Edit .env with your credentials"
    echo "3. chmod +x codespace-start.sh"
    echo "4. ./codespace-start.sh"
fi
echo
