### Context
- this project uses Spring Boot (Java) for the backend and Flutter (Dart) for the frontend



### Role
 You assist the developer with suggestions based on this file.
 Do not take autonomous actions, except in the following case:
    - When tests fail, you may autonomously analyze and identify the cause of the failure (log, configuration, data, code) without asking for permission.
    - When tests fail, you may PROPOSE corrections to the code, configuration, or data to resolve the issues detected in the tests
    - In tutti gli altri casi, prima di applicare modifiche al codice o alla configurazione, chiedi sempre conferma.
    - Before applying any code or configuration changes, always ask for confirmation.
 Propose changes to the instructions when new rules emerge.
 Strictly adhere to conventions.
 Use `// USER PREFERENCE:` or `// CUSTOM IMPLEMENTATION:` in comments to mark user-specified choices.
 Comment code only when necessary, avoid commenting obvious or self-explanatory code.
 Always check coherence between API and code.
 Respect the structure of Clean Architecture and SOLID principles.
 Comments in english, code in English, user interaction in Italian.


### TRIGGERS
Update these instructions immediately when user says:
- "direttiva:" or "directive:"
- "add this to instructions"
- Any permanent rule or convention is established

## DEVELOPMENT PRACTICES

### Test Data Loading
**ALWAYS use service layer instead of repository when loading test data in unit and integration tests.**  
**Prefer service calls over direct repository access to maintain proper separation of concerns and test business logic.**  
**Use repository directly only when specifically testing repository functionality.**

### Gestione Tipi Monetari
**DIRETTIVA: Nei DTO e Request utilizzare sempre `BigDecimal` per i campi monetari (amount, owedAmount, etc.)**
**Nel Model/Entity utilizzare `Double` per compatibilità MongoDB**
**I mapper devono gestire la conversione manuale tra `BigDecimal` (DTO) e `Double` (Model) usando `BigDecimal.valueOf()` e `.doubleValue()`**
**Motivazione: `BigDecimal` garantisce precisione nei calcoli monetari nelle API, mentre `Double` è più efficiente per storage MongoDB**

**Esempio di conversione corretta nei mapper:**
```java
// Model -> DTO: Double -> BigDecimal
dto.setAmount(model.getAmount() != null ? BigDecimal.valueOf(model.getAmount()) : null);

// DTO -> Model: BigDecimal -> Double  
model.setAmount(dto.getAmount() != null ? dto.getAmount().doubleValue() : null);
```

**NON utilizzare `BeanUtils.copyProperties()` per campi monetari - la conversione automatica fallisce.**

### Code Documentation
**Use `// USER PREFERENCE:` comments ONLY for significant user-specified choices:**
- User-specified implementation strategies that differ from standard practices
- Custom business logic or domain-specific patterns explicitly requested  
- Specific library/framework choices when user selects among alternatives

**Use `// CUSTOM IMPLEMENTATION:` for complex business logic requiring explanation.**

**DO NOT use these comments for:**
- Standard imports or dependencies
- Common framework annotations (Spring, JPA, validation)
- Obvious or self-explanatory code
- Routine technical choices following best practices

**Comment code only when it adds genuine value for understanding non-obvious decisions.**

### Initiative Guidelines
**When taking initiative to implement functionality, focus strictly on what was requested.**  
**If implementing a lot of stuff, ask for feedback between steps.**  
**Avoid adding extra endpoints, methods, or features beyond the specific requirement.**  
**If additional functionality would be helpful, ask if it should be implemented.**

### API Consistency
**ALWAYS ensure backend and frontend consistency when modifying endpoints, request/response formats, or authentication flows.**

### Code Verification
**ALWAYS check endpoint signatures and request/response structures in the code before making API calls.**  
**Never assume endpoint parameters - always verify in the controller and DTO classes.**

## 🚀 BUILD & DEPLOYMENT

### Build and Deploy
When asked to release components, use EXCLUSIVELY the existing scripts:

- **Backend**: `./backend/build-and-push-backend.sh auto`
- **Frontend**: `./frontend/build-and-push-frontend.sh auto` 
- **Both**: `./build-and-push.sh both auto`

**Versioning**: For daily development always increment `alpha` (parameter `auto`).

### GHCR Login
For GitHub Container Registry authentication: **invoke the `ghcr_login` function from `~/commands.sh`**

### Script Commands
- `./version.sh alpha` - Increment alpha for development
- `./version.sh patch` - Increment patch for bugfixes
- `./version.sh get` - Show current version

### Build Commands
- `./build-and-push.sh both auto` - Complete build with automatic versioning
- `./backend/build-and-push-backend.sh auto` - Backend only
- `./frontend/build-and-push-frontend.sh auto` - Frontend only

### Frontend Configuration (CRITICAL)
**BEFORE building for production, update `frontend/web/config.json`:**
- **Development**: `"apiUrl": "http://localhost:8080"`
- **Production**: `"apiUrl": "https://debt-collection-backend-latest.onrender.com"`

**Remember to switch back to localhost URL after production builds for local development.**

## 📋 TECHNOLOGY STACK

### Backend
- **Framework**: Spring Boot 3.2.3 + Java 17
- **Database**: PostgreSQL 
- **Security**: JWT + Spring Security
- **Architecture**: Clean Architecture with package `com.projectf`

### Frontend  
- **Framework**: Flutter 3.2.3+ + Dart 3.2+
- **State Management**: BLoC Pattern
- **UI**: Material Design 3
- **HTTP**: Dio with interceptors

### DevOps
- **Containers**: Docker + Multi-stage builds
- **Registry**: GitHub Container Registry (GHCR)
- **Versioning**: Automatic system with `version.sh`

## 🏗️ ARCHITECTURE & STRUCTURE

### Backend Structure
```
com.projectf/
├── controller/     # API endpoints
├── service/        # Business logic
├── repository/     # Data access
├── model/entity/   # JPA entities
├── dto/           # Data transfer objects
├── config/        # Spring configuration
└── security/      # JWT + filters
```

### Frontend Structure  
```
lib/
├── blocs/         # BLoC state management
├── models/        # Data models
├── services/      # API services
├── screens/       # UI screens
└── widgets/       # Reusable components
```

## 🔗 API CONVENTIONS

### Response Format (CRITICAL)
- ✅ **Success**: Data returned directly (NO wrapper)
- ❌ **Error**: `{"message": "...", "error": "ExceptionType"}`

### Endpoints
- **Base URL**: `/`
- **Auth**: `POST /auth/login`
- **Cases**: `GET /cases`

## 🔐 AUTHENTICATION AND SECURITY

### Authentication Flow
- **Login**: `POST /auth/login` with `username` and `password`
- **Response**: `{"token": "JWT_TOKEN", "passwordExpired": boolean}`
- **Headers**: Use `Authorization: Bearer {token}` for protected APIs

### Password Change
- **Endpoint**: `POST /auth/change-password` with `{"oldPassword": "admin", "newPassword": "Admin123!"}`
- **Validation**: Current password required + new password with security criteria
- **Flow**: On passwordExpired=true, force password change before access
- **JWT Flow**: 
  - Expired password: backend returns limited token (change password only) + `passwordExpired: true`
  - After password change: backend returns new token valid for all APIs

### Token Management
- **Storage**: Frontend uses `flutter_secure_storage` for JWT
- **Expired**: Backend returns 401, frontend must redirect to login
- **Logout**: Remove token from secure storage

### API Testing Procedure (CRITICAL)
**ALWAYS follow this exact sequence when testing backend APIs manually:**

1. **Login**: `POST /auth/login` with `{"username": "admin", "password": "admin"}`
   - Returns limited token with `passwordExpired: true` (works ONLY for password change)

2. **Change Password**: `POST /auth/change-password` with `{"oldPassword": "admin", "newPassword": "Admin123!"}`
   - Requires `Authorization: Bearer LIMITED_TOKEN` header
   - Returns full token with `passwordExpired: false`

3. **Use APIs**: All subsequent calls with `Authorization: Bearer FULL_TOKEN`

#### Security Requirements
- Input validation on ALL endpoints (backend + frontend)
- JWT protection for all protected APIs  
- Environment variables for credentials (never hardcoded)
- Bean Validation with `@Valid` on controllers

## ⚡ QUICK COMMANDS

### Development bash commands
# Login GHCR
source ~/commands.sh && ghcr_login

# Complete build
./build-and-push.sh both auto

# Individual components  
./backend/build-and-push-backend.sh auto
./frontend/build-and-push-frontend.sh auto

# USER PREFERENCE: Per questa fase di sviluppo, utilizzare esclusivamente data.sql sia in produzione che nei test. Non creare scipt sql solo per testing.
