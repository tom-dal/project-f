# Project F

Backend: Spring Boot (Java 21, MongoDB). Frontend: Flutter (web build). Repository integrates a single CI pipeline enforcing a coverage gate (soft at Maven level, hard at workflow level).

## CI Workflow (Build & Test)
Trigger: push on `main` (skips if commit message contains `[skip ci]`).

Steps summary:
1. Checkout, Java 21 setup (Maven cache).
2. Optional release bump (commit message exactly: `release: X.Y.Z`).
3. Backend `mvn clean verify` (Jacoco report generated; build itself never fails on coverage).
4. Coverage parsing (instruction). Threshold 85% (see exclusions); if below → workflow fails, no artifacts uploaded.
5. If coverage >=85%: copy backend JAR, setup Flutter stable, cache pub, `flutter build web --release`.
6. Upload artifacts: `backend-jar`, `frontend-web-dist` (retention 14 days).
7. Summary posted (overall coverage %, 10 worst classes).

### Coverage Policy
Threshold: 85% Instruction Coverage.
Excluded patterns (kept out of denominator):
- `**/dto/**`, `**/*Dto.class`, `**/*Request.class`, `**/*Response.class`
- Core model classes (Lombok-heavy): `DebtCase*`, `User*`, `StateTransitionConfig*`, `Payment*`, `CaseState*`, `Installment*`, `DebtCaseAudit*`
- Validation package INCLUDED (so business validation is measured).
Future target: progressively raise to 90% once test suite expands (remove model exclusions incrementally).

### Release Process
Commit message form: `release: X.Y.Z` (no extra text). The workflow:
- Bumps `backend/pom.xml` version to `X.Y.Z`.
- Commits with `chore: release version X.Y.Z [skip ci]` (prevents second run).
- Tags `vX.Y.Z` and pushes tag.
Artifacts for consumption come from the same run (before the bump commit is skipped). For persistent distribution consider adding a Release workflow that attaches the JAR to GitHub Release assets.

## Badges (replace `<org>` and `<repo>`)
| Purpose | Badge Markdown |
|---------|----------------|
| Build Status | `![CI](https://github.com/<org>/<repo>/actions/workflows/build.yml/badge.svg)` |
| Latest Release | `![Release](https://img.shields.io/github/v/release/<org>/<repo>?sort=semver)` |
| Coverage (manual) | `![Coverage](https://img.shields.io/badge/coverage-≥85%25-blue)` |

If you add an automated coverage uploader (Codecov/Sonar), update the coverage badge accordingly.

## Consuming the Backend JAR from Another Repository
Artifacts are tied to a workflow run and auto-expire (14 days). Options:

### Option A: GitHub CLI (manual / scripted)
```bash
# Set env vars
OWNER=<org>
REPO=<repo>
RUN_ID=$(gh run list -R "$OWNER/$REPO" -w "Build & Test" --limit 1 --json databaseId -q '.[0].databaseId')
# List artifacts of the run
gh run view $RUN_ID -R "$OWNER/$REPO" --json artifacts -q '.artifacts[] | [.name, .sizeInBytes]'
# Download backend jar artifact
gh run download $RUN_ID -R "$OWNER/$REPO" -n backend-jar -D ./downloaded
```
Jar will be under `downloaded/project-f-backend-<version>.jar`.

### Option B: API Download (CI in another repo)
1. Create a PAT (repo scope) or use a fine-grained token with read access.
2. Call list artifacts for latest successful run, then download by artifact ID.

Pseudo-script (bash + jq):
```bash
OWNER=<org>
REPO=<repo>
WF_ID=$(gh api repos/$OWNER/$REPO/actions/workflows | jq -r '.workflows[] | select(.name=="Build & Test") | .id')
RUN_ID=$(gh api repos/$OWNER/$REPO/actions/workflows/$WF_ID/runs?status=success | jq -r '.workflow_runs[0].id')
ART_ID=$(gh api repos/$OWNER/$REPO/actions/runs/$RUN_ID/artifacts | jq -r '.artifacts[] | select(.name=="backend-jar") | .id')
curl -L -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/actions/artifacts/$ART_ID/zip > backend-jar.zip
unzip backend-jar.zip -d backend-jar
```

### Option C: Promote to Release (Recommended for Stability)
Add a second job (or workflow) triggered on tag push (`v*`) that:
- Downloads jar artifact (`actions/download-artifact`).
- Publishes a GitHub Release attaching the JAR. Consumers can then fetch the release asset (stable URL).

Example snippet to add (not yet implemented):
```yaml
on:
  push:
    tags: [ "v*" ]
jobs:
  publish-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: backend-jar
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: project-f-backend-*.jar
```

## Frontend Web Build
Executed only if coverage threshold passes. Artifact `frontend-web-dist` contains `frontend/build/web` (e.g., deployable to static hosting or container base image). Extend later with a deployment job if needed.

## Increasing Coverage Strategy
1. Remove exclusions gradually (start with Payment*, User*).  
2. Add service-level tests for uncovered branches in `DebtCaseService`.  
3. Add controller integration tests for negative scenarios (state transitions, invalid installments) to raise branch coverage.

## Local Development Quickstart
```bash
cd backend
./mvnw spring-boot:run
# separate terminal
cd frontend
flutter pub get
flutter run -d chrome
```

## Notes
- Coverage gating logic lives in workflow only (not failing Maven).  
- Release commit includes `[skip ci]` to prevent duplicate run.  
- Adjust artifact retention or add release publishing when distribution cadence matures.

---
// CUSTOM IMPLEMENTATION: Coverage gate via workflow conditional artifact upload.

