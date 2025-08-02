#!/bin/bash

# Frontend Docker Build and Push Script
# Unified script fo# Step 3: Build Flutter web app for production
echo -e "${YELLOW}🔨 Building Flutter web app...${NC}"

# Build sempre senza dart-define per permettere configurazione runtime
echo -e "${BLUE}🌐 Building with runtime configuration support${NC}"
flutter build web --releaseFlutter web app and pushing Docker image to ghcr.io
# 
# Usage: ./build-and-push-frontend.sh [tag|auto|current]
# - auto: incrementa automaticamente la versione alpha
# - current: usa la versione corrente senza incrementare
# - tag specifico: usa il tag fornito
# Default tag: latest

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
NAMESPACE="tom-dal"
REPOSITORY="project-f/frontend"

# Gestione versioning automatico
if [ "$1" = "auto" ]; then
    echo -e "${YELLOW}🔄 Incrementando versione alpha automaticamente...${NC}"
    TAG=$(../version.sh alpha 2>/dev/null | tail -n 1)
    if [ $? -ne 0 ] || [ -z "$TAG" ]; then
        echo -e "${RED}❌ Errore nell'incremento della versione${NC}"
        exit 1
    fi
elif [ "$1" = "current" ]; then
    TAG=$(../version.sh get 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$TAG" ]; then
        echo -e "${RED}❌ Errore nel recupero della versione corrente${NC}"
        exit 1
    fi
else
    TAG="${1:-latest}"
fi

FULL_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${REPOSITORY}:${TAG}"
LATEST_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${REPOSITORY}:latest"

echo -e "${BLUE}=== Frontend Build and Push Script ===${NC}"
echo -e "${BLUE}Image: ${FULL_IMAGE_NAME}${NC}"
echo -e "${YELLOW}📦 Using tag: ${TAG}${NC}"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi

# Step 1: Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean
rm -rf build/

# Step 2: Get dependencies
echo -e "${YELLOW}📦 Getting Flutter dependencies...${NC}"
flutter pub get

# Step 3: Build Flutter web app for production
echo -e "${YELLOW}🔨 Building Flutter web app...${NC}"

# Use BACKEND_URL environment variable if provided, otherwise use production default
if [ -n "$BACKEND_URL" ]; then
    echo -e "${BLUE}🌐 Using custom backend URL: $BACKEND_URL${NC}"
    flutter build web --release --dart-define=BACKEND_URL="$BACKEND_URL"
else
    echo -e "${BLUE}🌐 Using production backend URL (default)${NC}"
    flutter build web --release --dart-define=BACKEND_URL="http://debt-collection-backend-latest.onrender.com/v1"
fi

# Check if build was successful
if [ ! -d "build/web" ]; then
    echo -e "${RED}❌ Flutter build failed - build/web directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Flutter web build completed${NC}"

# Step 4: Build Docker image with multi-platform support
echo -e "${YELLOW}🐳 Building Docker image (multi-platform)...${NC}"

# Create buildx builder if not exists
if ! docker buildx ls | grep -q "multiplatform"; then
    echo -e "${YELLOW}Creating buildx builder...${NC}"
    docker buildx create --name multiplatform --use
fi

# Use existing builder
docker buildx use multiplatform

# Build and push multi-platform image
if [ "$TAG" = "latest" ]; then
    # For latest tag, only push one image
    echo -e "${YELLOW}Building and pushing as latest...${NC}"
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "$LATEST_IMAGE_NAME" \
        --push \
        .
else
    # For other tags, push both the specific tag and latest
    echo -e "${YELLOW}Building and pushing as ${TAG} and latest...${NC}"
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "$FULL_IMAGE_NAME" \
        -t "$LATEST_IMAGE_NAME" \
        --push \
        .
fi

echo -e "${GREEN}✅ Docker image build and push completed${NC}"

# Step 5: Display results
echo ""
echo -e "${BLUE}=== Build Summary ===${NC}"
echo -e "${GREEN}✅ Flutter web app built successfully${NC}"
echo -e "${GREEN}✅ Docker image pushed to:${NC}"
if [ "$TAG" = "latest" ]; then
    echo -e "   📦 ${LATEST_IMAGE_NAME}"
else
    echo -e "   📦 ${FULL_IMAGE_NAME}"
    echo -e "   📦 ${LATEST_IMAGE_NAME}"
fi
echo ""
echo -e "${BLUE}🚀 Ready for deployment on Render!${NC}"
echo -e "${BLUE}Use image: ${LATEST_IMAGE_NAME}${NC}"
echo ""

# Step 6: Show next steps
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update your Render service to use the new image"
echo -e "2. Check deployment status on Render dashboard"
echo -e "3. Test the frontend at your Render URL"
echo ""
