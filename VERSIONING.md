# Automatic Versioning System

This project implements automatic versioning for Docker images using semantic versioning with alpha increments.

## 📦 Version Format

Versions follow semantic format: `MAJOR.MINOR.PATCH-alpha.ALPHA_NUM`

Example: `1.0.0-alpha.4`

## 🛠️ Essential Commands

### Check Version
```bash
./version.sh get                    # Show current version
```

### Build and Deploy
```bash
# Complete build with auto-increment
./build-and-push.sh both auto

# Individual components  
./backend/build-and-push-backend.sh auto
./frontend/build-and-push-frontend.sh auto
```

### Manual Version Updates
```bash
./version.sh alpha                  # Increment alpha: 1.0.0-alpha.4 → 1.0.0-alpha.5
./version.sh patch                  # Increment patch: 1.0.0-alpha.4 → 1.0.1-alpha.1
./version.sh minor                  # Increment minor: 1.0.0-alpha.4 → 1.1.0-alpha.1
./version.sh major                  # Increment major: 1.0.0-alpha.4 → 2.0.0-alpha.1
```

## 📋 Version File

The current version is stored in `version.json`:
```json
{
  "version": "1.0.0-alpha.5"
}
```

## 🏷️ Docker Tags

Each build creates:
- `ghcr.io/tom-dal/project-f/backend:latest`
- `ghcr.io/tom-dal/project-f/backend:1.0.0-alpha.5`
- `ghcr.io/tom-dal/project-f/frontend:latest`  
- `ghcr.io/tom-dal/project-f/frontend:1.0.0-alpha.5`

# Solo frontend
cd frontend
./build-and-push-frontend.sh auto
./build-and-push-frontend.sh current

# Solo versioning
./version.sh alpha                   # Incrementa alpha
./version.sh get                     # Mostra versione corrente
./version.sh get-alpha              # Mostra solo numero alpha
```

## 🔄 Workflow Tipico

### Sviluppo Giornaliero (Incremento Alpha)

```bash
# Incrementa versione alpha e fa build completo
./manage.sh build-all auto

# Output esempio:
# 🔄 Incrementando versione alpha automaticamente...
# ✅ Versione aggiornata: 1.0.0-alpha.4 → 1.0.0-alpha.5
# 🐳 Building and pushing Docker images to GHCR...
# 📦 Using tag: 1.0.0-alpha.5
```

### Release Patch

```bash
# Incrementa versione patch (reset alpha a 1)
./manage.sh version patch
# 1.0.0-alpha.5 → 1.0.1-alpha.1

# Build con nuova versione
./manage.sh build-all current
```

### Solo Backend/Frontend

```bash
# Solo backend con incremento automatico
./manage.sh build-backend auto

# Solo frontend con versione corrente
./manage.sh build-frontend current
```

## 📋 File di Configurazione

### `version.json`
Contiene la versione corrente in formato JSON:

```json
{
  "major": 1,
  "minor": 0,
  "patch": 0,
  "alpha": 4,
  "current": "1.0.0-alpha.4"
}
```

## 🏷️ Tagging delle Immagini

Ogni build crea due tag:
- **Tag specifico**: `ghcr.io/tom-dal/project-f/backend:1.0.0-alpha.5`
- **Tag latest**: `ghcr.io/tom-dal/project-f/backend:latest`

## 🔍 Controllo Versioni

```bash
# Versione corrente
./manage.sh version
# Output: 📦 Versione corrente: 1.0.0-alpha.4

# Solo il numero
./version.sh get
# Output: 1.0.0-alpha.4

# Solo il numero alpha
./version.sh get-alpha  
# Output: 4
```

## 🎯 Vantaggi del Sistema

1. **Automatico**: Non serve ricordare l'ultimo numero alpha
2. **Consistente**: Stesso versioning per backend e frontend
3. **Tracciabile**: Tutte le versioni sono registrate in `version.json`
4. **Flessibile**: Supporta sia incremento automatico che tag manuali
5. **Sicuro**: Validation degli incrementi e gestione errori

## 📁 Struttura File

```
project-f/
├── version.json                     # Configurazione versioni
├── version.sh                       # Script gestione versioni
├── manage.sh                       # Script unificato di gestione
├── build-and-push.sh              # Build completo (aggiornato)
├── backend/
│   └── build-and-push-backend.sh  # Build backend (aggiornato)
└── frontend/
    └── build-and-push-frontend.sh # Build frontend (aggiornato)
```

## 🚨 Note Importanti

- Gli script mantengono compatibilità con i tag manuali
- Il file `version.json` è l'unica fonte di verità per le versioni
- Tutti gli script hanno gestione errori e validation
- I build falliscono se il versioning non funziona correttamente
