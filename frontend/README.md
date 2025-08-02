# Debt Collection Manager - Frontend

Flutter web application for debt collection case management.

## 🚀 Quick Start

### Development
```bash
# Install dependencies
flutter pub get

# Run in development mode (uses localhost:8080 by default)
flutter run -d chrome

# Run with custom backend URL
flutter run -d chrome --dart-define=BACKEND_URL=http://192.168.1.100:8080/v1

# Run pointing to production backend
flutter run -d chrome --dart-define=BACKEND_URL=http://debt-collection-backend-latest.onrender.com/v1
```

### Environment Configuration

The frontend uses **runtime dynamic configuration** via `config.json`:

#### 🔧 Local Development:
```bash
# The web/config.json file is loaded automatically
# Edit web/config.json to point to your local backend
{
  "API_URL": "http://localhost:8080/v1"
}

# Then run normally
flutter run -d chrome
```

#### 🐳 Docker/Kubernetes:
```bash
# Use ConfigMap to override config.json
kubectl apply -f k8s-configmap.yaml
```

#### 📁 Configuration files available:
- `web/config.json` - Default for development
- `config/config.dev.json` - Development template  
- `config/config.prod.json` - Production template
- `k8s-configmap.yaml` - Kubernetes ConfigMap

## 🚀 Build & Deploy

```bash
# Build and push with automatic versioning
./build-and-push-frontend.sh auto

# Build with specific tag
./build-and-push-frontend.sh alpha

# Manual build
flutter build web --release
```

## 🐳 Docker

**Docker Image**: `ghcr.io/tom-dal/project-f/frontend:latest`

```bash
# Run locally
docker run -p 80:80 ghcr.io/tom-dal/project-f/frontend:latest
```

## 📁 Project Structure

- `lib/` - Source code
  - `screens/` - UI screens (login, dashboard)
  - `services/` - API services
  - `models/` - Data models
  - `blocs/` - BLoC state management
  - `widgets/` - Reusable components
- `web/` - Web assets and configuration
- `build/` - Build output (generated)

## 🧪 Testing

```bash
flutter test
```
