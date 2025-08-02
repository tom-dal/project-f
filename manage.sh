#!/bin/bash

# Script di utilità per la gestione delle versioni e build
# Fornisce comandi rapidi per versioning e deployment

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${BLUE}=== Gestione Versioni Docker - Project F ===${NC}"
    echo ""
    echo -e "${YELLOW}Comandi disponibili:${NC}"
    echo ""
    echo -e "${CYAN}VERSIONING:${NC}"
    echo "  ./manage.sh version                 - Mostra versione corrente"
    echo "  ./manage.sh version alpha           - Incrementa versione alpha"
    echo "  ./manage.sh version patch           - Incrementa versione patch (reset alpha a 1)"
    echo "  ./manage.sh version minor           - Incrementa versione minor (reset patch e alpha)"
    echo "  ./manage.sh version major           - Incrementa versione major (reset tutto)"
    echo ""
    echo -e "${CYAN}BUILD & DEPLOY:${NC}"
    echo "  ./manage.sh build-all auto          - Build completo con versione alpha incrementale"
    echo "  ./manage.sh build-all current       - Build completo con versione corrente"
    echo "  ./manage.sh build-all [tag]         - Build completo con tag specifico"
    echo "  ./manage.sh build-backend auto      - Build solo backend con versione incrementale"
    echo "  ./manage.sh build-frontend auto     - Build solo frontend con versione incrementale"
    echo ""
    echo -e "${CYAN}ESEMPI:${NC}"
    echo "  ./manage.sh version alpha           # 1.0.0-alpha.4 → 1.0.0-alpha.5"
    echo "  ./manage.sh build-all auto          # Build completo con versione incrementata"
    echo "  ./manage.sh build-backend current   # Build backend con versione corrente"
    echo ""
}

show_version() {
    local current_version=$(./version.sh get 2>/dev/null | tail -n 1)
    if [ $? -eq 0 ] && [ ! -z "$current_version" ]; then
        echo -e "${GREEN}📦 Versione corrente: $current_version${NC}"
    else
        echo -e "${RED}❌ Errore nel recupero della versione${NC}"
        exit 1
    fi
}

increment_version() {
    local type=$1
    echo -e "${YELLOW}🔄 Incrementando versione $type...${NC}"
    local new_version=$(./version.sh $type 2>/dev/null | tail -n 1)
    if [ $? -eq 0 ] && [ ! -z "$new_version" ]; then
        echo -e "${GREEN}✅ Nuova versione: $new_version${NC}"
    else
        echo -e "${RED}❌ Errore nell'incremento della versione${NC}"
        exit 1
    fi
}

build_all() {
    local tag_mode=$1
    echo -e "${BLUE}🚀 Avviando build completo...${NC}"
    
    if [ "$tag_mode" = "auto" ]; then
        echo -e "${YELLOW}📦 Modalità auto: incrementerà la versione alpha${NC}"
    elif [ "$tag_mode" = "current" ]; then
        echo -e "${YELLOW}📦 Modalità current: userà la versione corrente${NC}"
        show_version
    else
        echo -e "${YELLOW}📦 Usando tag: $tag_mode${NC}"
    fi
    
    echo ""
    ./build-and-push.sh $tag_mode
}

build_backend() {
    local tag_mode=$1
    echo -e "${BLUE}🔨 Build backend...${NC}"
    cd backend
    ./build-and-push-backend.sh $tag_mode
    cd ..
}

build_frontend() {
    local tag_mode=$1
    echo -e "${BLUE}🎨 Build frontend...${NC}"
    cd frontend
    ./build-and-push-frontend.sh $tag_mode
    cd ..
}

# Parse dei comandi
case "$1" in
    "version")
        if [ -z "$2" ]; then
            show_version
        else
            increment_version $2
        fi
        ;;
    "build-all")
        build_all ${2:-auto}
        ;;
    "build-backend")
        build_backend ${2:-auto}
        ;;
    "build-frontend")
        build_frontend ${2:-auto}
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        if [ -z "$1" ]; then
            show_help
        else
            echo -e "${RED}❌ Comando non riconosciuto: $1${NC}"
            echo ""
            show_help
            exit 1
        fi
        ;;
esac
