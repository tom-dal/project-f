#!/bin/bash

# DEPRECATO: Usa solo build-and-push-backend.sh
# Questo script non è più mantenuto. Per build e push usa:
#   ./build-and-push-backend.sh [alpha-tag]
# Rimane solo per compatibilità temporanea.

# Script per build veloce dell'immagine Docker
# Builda prima con Maven, poi crea l'immagine Docker

set -e

echo "🔨 Building JAR with Maven..."
./mvnw clean package -DskipTests

echo "🐳 Building Docker image..."
docker buildx build --platform linux/amd64 -t ghcr.io/tom-dal/debt-collection-manager:latest -f Dockerfile.fast --load .

echo "✅ Build completato!"
echo ""
echo "Per pushare l'immagine:"
echo "docker push ghcr.io/tom-dal/debt-collection-manager:latest"
echo ""
echo "Per testare localmente:"
echo "export DB_PASSWORD=\"your_password_here\""
echo "./start-app.sh"
echo ""
echo "Oppure direttamente:"
echo "DB_PASSWORD=\"your_password_here\" docker run -e DB_PASSWORD=\"\$DB_PASSWORD\" ghcr.io/tom-dal/debt-collection-manager:latest"
