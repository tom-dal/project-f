# Project F - Debt Collection Manager

Debt collection management system with Spring Boot backend and Flutter frontend.

## 🚀 Quick Start

### Build and Deploy
```bash
# Complete build with automatic versioning
./build-and-push.sh both auto

# Individual components
./backend/build-and-push-backend.sh auto     # Backend only  
./frontend/build-and-push-frontend.sh auto   # Frontend only

# Check current version
./version.sh get
```

### Login to GHCR
```bash
# Authentication for GitHub Container Registry
source ~/commands.sh && ghcr_login
```

## 🏗️ Architecture

- **Backend**: Spring Boot 3.2.3 + Java 17 + PostgreSQL
- **Frontend**: Flutter 3.2.3+ + Dart 3.2+
- **Deployment**: Docker + GitHub Container Registry
- **Versioning**: Automatic semantic versioning

## 🔐 Authentication

- **Login**: `POST /auth/login` 
- **Change Password**: `POST /auth/change-password`
- **JWT Token**: Required for protected endpoints

## 🐳 Docker Images

```bash
# Backend
ghcr.io/tom-dal/project-f/backend:latest

# Frontend  
ghcr.io/tom-dal/project-f/frontend:latest
```

## 📖 Documentation

- **[📦 Versioning System](VERSIONING.md)** - Automatic versioning system
- **[🎨 Frontend Guide](frontend/README.md)** - Flutter frontend guide

## 🔧 Development

### Backend
```bash
cd backend
./mvnw spring-boot:run    # Run locally
./mvnw test               # Run tests
```

### Frontend
```bash
cd frontend
flutter pub get           # Install dependencies
flutter run -d chrome     # Run locally
flutter test              # Run tests
```