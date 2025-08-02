#!/bin/bash

# DEPRECATO: Usa solo build-and-push-backend.sh
# Questo script non è più mantenuto. Per build e push usa:
#   ./build-and-push-backend.sh [alpha-tag]
# Rimane solo per compatibilità temporanea.

# Script per avviare l'applicazione debt-collection con Docker
# Database: Render PostgreSQL
# 
# Uso: 
#   export DB_PASSWORD="your_password_here"
#   ./start-app.sh
# 
# Oppure:
#   DB_PASSWORD="your_password_here" ./start-app.sh

# Verifica che la password sia stata fornita
if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Errore: DB_PASSWORD non impostata!"
    echo "Usa: export DB_PASSWORD=\"your_password_here\" && ./start-app.sh"
    echo "Oppure: DB_PASSWORD=\"your_password_here\" ./start-app.sh"
    exit 1
fi

echo "🚀 Avviando debt-collection-backend..."

docker run --rm -p 8080:8080 \
  --name debt-collection-backend \
  -e DB_HOST=dpg-d0vhub3uibrs73e8nlc0-a.frankfurt-postgres.render.com \
  -e DB_PORT=5432 \
  -e DB_NAME=debt_manager \
  -e DB_USERNAME=tommaso \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  ghcr.io/tom-dal/debt-collection-manager:latest

echo "✅ Applicazione avviata su http://localhost:8080"
echo "📊 Health check: curl http://localhost:8080/api/actuator/health"
