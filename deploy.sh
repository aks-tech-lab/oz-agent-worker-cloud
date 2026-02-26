#!/bin/bash
set -euo pipefail

# =============================================================================
# Deployment script for oz-agent-worker on DEPLOY branch
# =============================================================================

echo "======================================"
echo "oz-agent-worker DEPLOY Branch Setup"
echo "======================================"
echo

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo "Error: git is not installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed"; exit 1; }

# Configuration
REPO_DIR="/workspaces/oz-agent-worker-cloud"
IMAGE_NAME="ghcr.io/aks-tech-lab/oz-warp.aknibir.systems"
BRANCH_NAME="DEPLOY"

cd "$REPO_DIR"

# Step 1: Git operations
echo "[1/6] Creating and pushing DEPLOY branch..."
echo "-------------------------------------------"

# Check if we have uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "Uncommitted changes detected. Staging all files..."
    git add .
    git commit -m "Add deployment configuration, workflows, and Cloudflare tunnel setup" || true
fi

# Create or switch to DEPLOY branch
if git show-ref --verify --quiet refs/heads/DEPLOY; then
    echo "DEPLOY branch exists. Switching to it..."
    git checkout DEPLOY
else
    echo "Creating new DEPLOY branch..."
    git checkout -b DEPLOY
fi

# Push to remote
echo "Pushing DEPLOY branch to origin..."
if git push -u origin DEPLOY 2>/dev/null; then
    echo "✓ Successfully pushed DEPLOY branch"
else
    echo "⚠ Could not push to origin (may need authentication or remote setup)"
    echo "  You can push manually later with: git push -u origin DEPLOY"
fi

echo

# Step 2: Build Docker image
echo "[2/6] Building Docker image..."
echo "-------------------------------------------"

if docker buildx version >/dev/null 2>&1; then
    echo "Using buildx for multi-platform build..."
    docker buildx create --use --name oz-warp-builder 2>/dev/null || docker buildx use oz-warp-builder
    
    echo "Building for linux/amd64 and linux/arm64..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "${IMAGE_NAME}:latest" \
        -t "${IMAGE_NAME}:$(git rev-parse --short HEAD)" \
        --load \
        .
else
    echo "Building single-platform image..."
    docker build -t "${IMAGE_NAME}:latest" -t "${IMAGE_NAME}:$(git rev-parse --short HEAD)" .
fi

echo "✓ Docker image built successfully"
echo

# Step 3: Push to GHCR
echo "[3/6] Pushing to GitHub Container Registry..."
echo "-------------------------------------------"

if docker info 2>/dev/null | grep -q "Username.*ghcr.io"; then
    echo "Already logged in to GHCR"
else
    echo "Please log in to GHCR (GitHub Container Registry):"
    echo ""
    echo "Get a token at: https://github.com/settings/tokens/new"
    echo "Required scopes: write:packages, read:packages"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN=ghp_your_token_here"
    echo "  export GITHUB_USERNAME=aks-tech-lab"
    echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u \$GITHUB_USERNAME --password-stdin"
    echo ""
    read -p "Press Enter once logged in, or Ctrl+C to skip..."
fi

echo "Pushing ${IMAGE_NAME}:latest..."
if docker push "${IMAGE_NAME}:latest"; then
    echo "✓ Successfully pushed to GHCR"
else
    echo "⚠ Push failed. Check authentication and repository permissions."
    echo "  View the image locally: docker images | grep oz-warp"
fi

echo

# Step 4: Cloudflare Tunnel Setup
echo "[4/6] Cloudflare Tunnel configuration..."
echo "-------------------------------------------"

if command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared is installed: $(cloudflared --version)"
    
    if [[ ! -f ~/.cloudflared/cert.pem ]]; then
        echo "⚠ Not authenticated with Cloudflare. Run:"
        echo "  cloudflared tunnel login"
    else
        echo "✓ Cloudflare authenticated"
        
        # Check if tunnel exists
        if cloudflared tunnel list 2>/dev/null | grep -q "oz-warp"; then
            echo "✓ Tunnel 'oz-warp' already exists"
        else
            echo "Creating tunnel 'oz-warp'..."
            cloudflared tunnel create oz-warp
        fi
        
        # Get tunnel ID
        TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep oz-warp | awk '{print $1}')
        if [[ -n "$TUNNEL_ID" ]]; then
            echo "Tunnel ID: $TUNNEL_ID"
            
            # Update config with tunnel ID
            if [[ -f cloudflare-tunnel-config.yml ]]; then
                sed -i "s/<tunnel-id>/${TUNNEL_ID}/g" cloudflare-tunnel-config.yml
                echo "✓ Updated cloudflare-tunnel-config.yml with tunnel ID"
            fi
        fi
    fi
else
    echo "⚠ cloudflared not installed. Install from:"
    echo "  https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
fi

echo

# Step 5: Environment setup
echo "[5/6] Environment configuration..."
echo "-------------------------------------------"

if [[ ! -f .env ]]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo "⚠ Please edit .env and add your WARP_API_KEY and WORKER_ID"
    echo "  nano .env"
else
    echo "✓ .env file exists"
fi

# Check if WARP_API_KEY is set
if grep -q "^WARP_API_KEY=wk-" .env 2>/dev/null && grep -q "^WORKER_ID=" .env 2>/dev/null; then
    echo "✓ Environment variables configured"
else
    echo "⚠ Please configure WARP_API_KEY and WORKER_ID in .env"
fi

echo

# Step 6: Verification
echo "[6/6] Verification checks..."
echo "-------------------------------------------"

echo "Checking Docker daemon..."
if docker ps >/dev/null 2>&1; then
    echo "✓ Docker daemon is accessible"
else
    echo "✗ Cannot access Docker daemon"
    echo "  Check: docker ps"
fi

echo
echo "Checking network connectivity to Warp..."
if curl -s -I https://oz.warp.dev >/dev/null 2>&1; then
    echo "✓ Can reach oz.warp.dev"
else
    echo "⚠ Cannot reach oz.warp.dev (check network/firewall)"
fi

echo
echo "======================================"
echo "Deployment Setup Complete!"
echo "======================================"
echo
echo "Next steps:"
echo "1. Review and edit .env file with your credentials"
echo "2. Configure Cloudflare DNS records for oz-warp.aknibir.systems"
echo "3. Start the Cloudflare tunnel:"
echo "   sudo cloudflared tunnel --config /etc/cloudflared/config.yml run oz-warp"
echo "4. Run the worker:"
echo "   docker run -d --name oz-agent-worker \\"
echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "     -e WARP_API_KEY=\"\$(grep WARP_API_KEY .env | cut -d= -f2)\" \\"
echo "     ${IMAGE_NAME}:latest \\"
echo "     --worker-id \"\$(grep WORKER_ID .env | cut -d= -f2)\""
echo
echo "Full documentation: See DEPLOYMENT.md"
echo
