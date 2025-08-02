# Backend Docker Guide

## 🚀 Quick Build and Deploy

```bash
cd backend
./build-and-push-backend.sh auto
```

This script:
1. Compiles JAR with Maven
2. Builds multi-platform Docker image (linux/amd64)
3. Pushes to `ghcr.io/tom-dal/project-f/backend:latest`
4. Auto-increments version tag

## 🐳 Docker Image Details

- **Registry**: `ghcr.io/tom-dal/project-f/backend`
- **Platform**: linux/amd64, linux/arm64
- **Size**: ~470MB
- **Base**: Eclipse Temurin 17 JRE
- **Security**: Non-root user (`appuser`)
- **Health Check**: `/actuator/health`

## 🔧 Local Development

### Run Locally
```bash
docker run --rm -p 8080:8080 \
  -e DB_HOST=localhost \
  -e DB_PORT=5432 \
  -e DB_NAME=debt_manager \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=your_password \
  ghcr.io/tom-dal/project-f/backend:latest
```

### Development with Docker Compose
```bash
docker-compose up
```

## 📋 Environment Variables

### Required
- `DB_HOST` - Database host
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name
- `DB_USERNAME` - Database username  
- `DB_PASSWORD` - Database password

### Optional
- `JAVA_OPTS` - JVM options (default: `-Xmx512m -Xms256m`)
- `SPRING_PROFILES_ACTIVE` - Spring profile (default: `production`)
- `PORT` - Application port (default: 8080)
- `LOGGING_LEVEL_ROOT` - Root logging level (default: INFO)

## 🔍 Health Check

The image includes a built-in health check:
```bash
curl http://localhost:8080/actuator/health
```

## 📁 Dockerfile

Uses `Dockerfile.optimized` for production builds with dependency layer caching.
