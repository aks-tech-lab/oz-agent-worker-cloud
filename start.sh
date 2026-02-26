#!/bin/bash
# Quick start script for running oz-agent-worker locally

set -euo pipefail

echo "oz-agent-worker Quick Start"
echo "============================="
echo

# Check for .env file
if [[ ! -f .env ]]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo
    echo "⚠️  Please edit .env and set:"
    echo "   - WARP_API_KEY (your Warp platform API key)"
    echo "   - WORKER_ID (unique identifier, must not start with 'warp')"
    echo
    echo "Then run this script again."
    exit 1
fi

# Source environment variables
export $(grep -v '^#' .env | xargs)

# Validate required variables
if [[ -z "${WARP_API_KEY:-}" ]] || [[ "$WARP_API_KEY" == "wk-" ]]; then
    echo "❌ WARP_API_KEY not set in .env"
    exit 1
fi

if [[ -z "${WORKER_ID:-}" ]] || [[ "$WORKER_ID" == "my-worker" ]]; then
    echo "❌ WORKER_ID not set in .env"
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
    echo "   Make sure Docker is running: sudo systemctl start docker"
    exit 1
fi
echo "✓ Docker daemon accessible"
echo

# Build the binary
echo "Building oz-agent-worker..."
if command -v go >/dev/null 2>&1; then
    go build -o oz-agent-worker .
    echo "✓ Built successfully"
else
    echo "⚠️  Go not installed, will use Docker image instead"
    WORKER_BIN="docker"
fi

echo
echo "Starting oz-agent-worker..."
echo "============================="

if [[ "${WORKER_BIN:-}" == "docker" ]]; then
    # Run from Docker image
    docker run -it --rm \
        --name oz-agent-worker \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e WARP_API_KEY="$WARP_API_KEY" \
        ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest \
        --worker-id "$WORKER_ID" \
        --log-level "${LOG_LEVEL:-info}"
else
    # Run the local binary
    ./oz-agent-worker \
        --api-key "$WARP_API_KEY" \
        --worker-id "$WORKER_ID" \
        --log-level "${LOG_LEVEL:-info}"
fi
