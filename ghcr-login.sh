#!/bin/bash
# Quick GHCR login and pull script

set -euo pipefail

echo "=========================================="
echo "GHCR (GitHub Container Registry) Setup"
echo "=========================================="
echo

# Check if already logged in
if docker system info 2>/dev/null | grep -q "Username"; then
    CURRENT_USER=$(docker system info 2>/dev/null | grep "Username" | cut -d: -f2 | xargs)
    echo "✓ Already logged in as: $CURRENT_USER"
    echo
else
    echo "Not logged in to any Docker registry"
    echo
fi

# Prompt for credentials if not set
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "GitHub Token not found in environment."
    echo
    echo "Get a token at: https://github.com/settings/tokens/new"
    echo "Required scopes: write:packages, read:packages"
    echo
    read -p "Enter your GitHub token (ghp_...): " GITHUB_TOKEN
    export GITHUB_TOKEN
fi

if [[ -z "${GITHUB_USERNAME:-}" ]]; then
    read -p "Enter your GitHub username [aks-tech-lab]: " GITHUB_USERNAME
    GITHUB_USERNAME=${GITHUB_USERNAME:-aks-tech-lab}
    export GITHUB_USERNAME
fi

# Login to GHCR
echo
echo "Logging in to ghcr.io as $GITHUB_USERNAME..."
if echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin 2>/dev/null; then
    echo "✓ Successfully logged in to GHCR"
else
    echo "❌ Login failed. Check your token and username."
    exit 1
fi

# Set image name
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/aks-tech-lab/oz-warp.aknibir.systems:latest}"

echo
echo "Pulling image: $IMAGE_NAME"
if docker pull "$IMAGE_NAME"; then
    echo "✓ Successfully pulled image"
else
    echo "❌ Failed to pull image. Check:"
    echo "  1. Image name is correct"
    echo "  2. Token has read:packages scope"
    echo "  3. Package exists and is accessible"
    exit 1
fi

echo
echo "=========================================="
echo "✓ GHCR setup complete!"
echo "=========================================="
echo
echo "Your image is ready to use:"
echo "  $IMAGE_NAME"
echo
echo "Run the worker:"
echo "  docker run -d \\"
echo "    --name oz-agent-worker \\"
echo "    -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "    -e WARP_API_KEY=\"your-key\" \\"
echo "    $IMAGE_NAME \\"
echo "    --worker-id \"your-worker-id\""
echo
