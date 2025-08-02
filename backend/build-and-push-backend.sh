#!/bin/bash
# Unified build and push script for Debt Collection Backend (multi-platform, alpha/latest tags)
# DEPRECATES: fast-build.sh, manual docker build commands
# Usage: ./build-and-push-backend.sh [tag|auto|current]
# - auto: incrementa automaticamente la versione alpha
# - current: usa la versione corrente senza incrementare
# - tag specifico: usa il tag fornito

set -e

# Configuration
IMAGE="ghcr.io/tom-dal/project-f/backend"
TAG_LATEST="latest"
GITHUB_USERNAME="tom-dal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Gestione versioning automatico
if [ "$1" = "auto" ]; then
    echo "🔄 Incrementando versione alpha automaticamente..."
    TAG_ALPHA=$(../version.sh alpha 2>/dev/null | tail -n 1)
    if [ $? -ne 0 ] || [ -z "$TAG_ALPHA" ]; then
        echo "❌ Errore nell'incremento della versione"
        exit 1
    fi
elif [ "$1" = "current" ]; then
    TAG_ALPHA=$(../version.sh get 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$TAG_ALPHA" ]; then
        echo "❌ Errore nel recupero della versione corrente"
        exit 1
    fi
else
    TAG_ALPHA="${1:-1.0.0-alpha.4}"
fi

cd "$(dirname "$0")"

echo "📦 Using version: $TAG_ALPHA"

# Login a GHCR
echo "🔐 Logging in to GitHub Container Registry..."
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

echo "[1/3] Building JAR with Maven..."
./mvnw clean package -DskipTests

echo "[2/3] Building & pushing Docker image ($IMAGE:$TAG_ALPHA, $IMAGE:$TAG_LATEST) for linux/amd64..."
docker buildx build --platform linux/amd64 -f Dockerfile.optimized -t $IMAGE:$TAG_ALPHA -t $IMAGE:$TAG_LATEST . --push

echo "✅ Done. Image pushed as $IMAGE:$TAG_ALPHA and $IMAGE:$TAG_LATEST"
