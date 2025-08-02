#!/bin/bash

# Source the commands file for ghcr_login function
source /Users/tommaso/commands.sh

# Script per build e push delle immagini Docker su GHCR
# Uso: ./build-and-push.sh [component] [version]
# component: backend, frontend, both (default: both)
# version: auto, current, or specific tag (default: latest)

set -e

# Configurazione
REGISTRY="ghcr.io"
GITHUB_USERNAME="tom-dal"
PROJECT_NAME="project-f"

# Parsing parametri
COMPONENT=${1:-both}
VERSION_PARAM=${2:-latest}

# Gestione versioning automatico
if [ "$VERSION_PARAM" = "auto" ]; then
    echo "🔄 Incrementando versione alpha automaticamente..."
    TAG=$(./version.sh alpha 2>/dev/null | tail -n 1)
    if [ $? -ne 0 ] || [ -z "$TAG" ]; then
        echo "❌ Errore nell'incremento della versione"
        exit 1
    fi
elif [ "$VERSION_PARAM" = "current" ]; then
    TAG=$(./version.sh get 2>/dev/null | tail -n 1)
    if [ $? -ne 0 ] || [ -z "$TAG" ]; then
        echo "❌ Errore nel recupero della versione corrente"
        exit 1
    fi
else
    # Tag specificato o default
    TAG=$VERSION_PARAM
fi

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🐳 Building and pushing Docker images to GHCR...${NC}"
echo -e "${YELLOW}📦 Component: ${COMPONENT}, Tag: ${TAG}${NC}"

# Login a GHCR
ghcr_login

# Build Backend
if [ "$COMPONENT" = "backend" ] || [ "$COMPONENT" = "both" ]; then
    echo -e "${YELLOW}🔨 Building Backend Docker image...${NC}"
    cd backend
    docker buildx build --platform linux/amd64,linux/arm64 -t ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/backend:${TAG} -t ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/backend:latest --push .
    cd ..
    echo -e "${GREEN}✅ Backend build completed!${NC}"
fi

# Build Frontend
if [ "$COMPONENT" = "frontend" ] || [ "$COMPONENT" = "both" ]; then
    echo -e "${YELLOW}🔨 Building Frontend...${NC}"
    cd frontend

    # Build Flutter web se non esiste già
    if [ ! -d "build/web" ]; then
        echo -e "${YELLOW}📱 Building Flutter web app...${NC}"
        flutter pub get
        flutter build web --release
    fi

    echo -e "${YELLOW}🔨 Building Frontend Docker image...${NC}"
    docker buildx build --platform linux/amd64,linux/arm64 -t ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/frontend:${TAG} -t ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/frontend:latest --push .
    cd ..
    echo -e "${GREEN}✅ Frontend build completed!${NC}"
fi

echo -e "${GREEN}✅ Successfully built and pushed images!${NC}"
if [ "$COMPONENT" = "backend" ] || [ "$COMPONENT" = "both" ]; then
    echo -e "${GREEN}Backend: ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/backend:${TAG}${NC}"
fi
if [ "$COMPONENT" = "frontend" ] || [ "$COMPONENT" = "both" ]; then
    echo -e "${GREEN}Frontend: ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/frontend:${TAG}${NC}"
fi

# Crea docker-compose.yml per deployment solo se sono stati buildati entrambi i componenti
if [ "$COMPONENT" = "both" ]; then
    echo -e "${YELLOW}📄 Creating docker-compose.yml for deployment...${NC}"
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  backend:
    image: ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/backend:${TAG}
    container_name: debt-collection-backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=production
      - DB_HOST=\${DB_HOST:-localhost}
      - DB_PORT=\${DB_PORT:-5432}
      - DB_NAME=\${DB_NAME:-debtcollection}
      - DB_USERNAME=\${DB_USERNAME:-dbuser}
      - DB_PASSWORD=\${DB_PASSWORD}
      - JAVA_OPTS=-Xmx512m -Xms256m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - debt-collection-network

  frontend:
    image: ${REGISTRY}/${GITHUB_USERNAME}/${PROJECT_NAME}/frontend:${TAG}
    container_name: debt-collection-frontend
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - debt-collection-network

networks:
  debt-collection-network:
    driver: bridge

# Per usare questo docker-compose:
# 1. Crea un file .env con le variabili del database:
#    DB_HOST=your-db-host
#    DB_PORT=5432
#    DB_NAME=debtcollection
#    DB_USERNAME=your-username
#    DB_PASSWORD=your-password
# 2. Esegui: docker-compose up -d
EOF

    echo -e "${GREEN}✅ Created docker-compose.yml for deployment${NC}"
    echo -e "${YELLOW}💡 To deploy: Create .env file with DB credentials and run 'docker-compose up -d'${NC}"
fi
