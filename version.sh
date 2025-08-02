#!/bin/bash

# Script per gestire le versioni incrementali delle immagini Docker
# Supporta i pattern di versioning semantico con suffisso alpha
# Uso: ./version.sh [increment-type]
# Tipi di incremento: alpha, patch, minor, major

set -e

VERSION_FILE="version.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_PATH="$SCRIPT_DIR/$VERSION_FILE"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per leggere il valore dal JSON
get_version_value() {
    local key=$1
    python3 -c "import json; data=json.load(open('$VERSION_PATH')); print(data['$key'])"
}

# Funzione per aggiornare il JSON
update_version() {
    local major=$1
    local minor=$2
    local patch=$3
    local alpha=$4
    local current="$major.$minor.$patch-alpha.$alpha"
    
    cat > "$VERSION_PATH" << EOF
{
  "major": $major,
  "minor": $minor,
  "patch": $patch,
  "alpha": $alpha,
  "current": "$current"
}
EOF
}

# Verifica che esista il file version.json
if [ ! -f "$VERSION_PATH" ]; then
    echo -e "${RED}❌ File version.json non trovato in $VERSION_PATH${NC}"
    exit 1
fi

# Legge la versione corrente
CURRENT_MAJOR=$(get_version_value "major")
CURRENT_MINOR=$(get_version_value "minor")
CURRENT_PATCH=$(get_version_value "patch")
CURRENT_ALPHA=$(get_version_value "alpha")
CURRENT_VERSION=$(get_version_value "current")

echo -e "${BLUE}📦 Versione corrente: $CURRENT_VERSION${NC}"

# Determina il tipo di incremento
INCREMENT_TYPE=${1:-alpha}

case $INCREMENT_TYPE in
    "alpha")
        NEW_MAJOR=$CURRENT_MAJOR
        NEW_MINOR=$CURRENT_MINOR
        NEW_PATCH=$CURRENT_PATCH
        NEW_ALPHA=$((CURRENT_ALPHA + 1))
        ;;
    "patch")
        NEW_MAJOR=$CURRENT_MAJOR
        NEW_MINOR=$CURRENT_MINOR
        NEW_PATCH=$((CURRENT_PATCH + 1))
        NEW_ALPHA=1
        ;;
    "minor")
        NEW_MAJOR=$CURRENT_MAJOR
        NEW_MINOR=$((CURRENT_MINOR + 1))
        NEW_PATCH=0
        NEW_ALPHA=1
        ;;
    "major")
        NEW_MAJOR=$((CURRENT_MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        NEW_ALPHA=1
        ;;
    "get")
        echo "$CURRENT_VERSION"
        exit 0
        ;;
    "get-alpha")
        echo "$CURRENT_ALPHA"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Tipo di incremento non valido: $INCREMENT_TYPE${NC}"
        echo -e "${YELLOW}Tipi supportati: alpha, patch, minor, major, get, get-alpha${NC}"
        exit 1
        ;;
esac

# Aggiorna la versione
update_version $NEW_MAJOR $NEW_MINOR $NEW_PATCH $NEW_ALPHA
NEW_VERSION="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH-alpha.$NEW_ALPHA"

echo -e "${GREEN}✅ Versione aggiornata: $CURRENT_VERSION → $NEW_VERSION${NC}"
echo -e "${YELLOW}💡 Nuova versione: $NEW_VERSION${NC}"

# Output della nuova versione per script che la chiamano
echo "$NEW_VERSION"
