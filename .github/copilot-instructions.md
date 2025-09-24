# Repository AI Instructions

## 1. Scope & Precedence
Istruzioni vincolanti per l’assistente AI su questo repository (Backend Spring Boot + MongoDB, Frontend Flutter). Se una risposta di sistema esterna confligge, prevalgono le Hard Directives (sez. 4). Interazione utente in italiano; codice e commenti tecnici in inglese.

## 2. Tech Stack (Current)
Backend: Spring Boot 3.x, Java 17, MongoDB, JWT (Spring Security).  
Frontend: Flutter 3.x, Dart 3.x, BLoC, Dio, Material 3.  
Storage: MongoDB (motivazione uso Double nelle entity per campi monetari).

## 3. Interaction Style
- Italiano verso l’utente.
- Concisione: niente filler, frasi di cortesia superflue, hype.
- Spiegazioni solo per decisioni non ovvie o potenziali impatti.
- Porre domande solo se un’informazione mancante blocca l’esecuzione.
- Chiedere conferma prima di modificare file (eccezione: analisi fallimenti test—solo diagnosi e proposta).
- Nessuna funzionalità extra non richiesta.
- Evidenziare scelte utente con `// USER PREFERENCE:` e logica custom non banale con `// CUSTOM IMPLEMENTATION:`.
- Lunghezza: target ≤180 parole per risposte standard.
- Eccezione: superare il limite solo se necessario per concetti complessi o diagnosi profonde (esplicitare quando avviene).
- Risposte lunghe: prima un riepilogo (≤8 righe), poi dettagli opzionali in blocchi numerati.
- Codice: includere solo frammenti essenziali; evitare file completi salvo richiesta esplicita.
- Log / output voluminosi: fornire prima un riassunto e chiedere se mostrare il dettaglio.

## 4. Hard Directives (Non derogabili)
### 4.1 Test Data Loading  
- Nei test (unit + integration) creare e caricare dati tramite service layer.  
- Repository diretto solo per testarne il comportamento.

### 4.2 Monetary Types  
- DTO / Request: BigDecimal  
- Entity / Model: Double (compatibilità e serializzazione leggera con MongoDB)  
- Mapper: conversione manuale (no BeanUtils)  
```java
// Model -> DTO
dto.setAmount(model.getAmount() != null ? BigDecimal.valueOf(model.getAmount()) : null);
// DTO -> Model
model.setAmount(dto.getAmount() != null ? dto.getAmount().doubleValue() : null);
```
- Motivazione: precisione lato API (BigDecimal), storage leggero e compatto lato MongoDB (Double). Calcoli critici sempre con BigDecimal nel layer di servizio.

### 4.3 API Response Format  
- Successo: payload diretto (no wrapper).  
- Errore: {"message":"...","error":"ExceptionType"}

### 4.4 API Contract Discipline  
- Verificare sempre Controller + DTO prima di assumere schema.  
- Evidenziare esplicitamente ogni breaking change e attendere conferma.

### 4.5 Security Flow (Auth)  
1. POST /auth/login → token limitato + passwordExpired:true (password iniziale)  
2. POST /auth/change-password → token completo + passwordExpired:false  
3. API protette → Authorization: Bearer FULL_TOKEN  
- 401 → frontend invalida token e reindirizza login  
- Ogni endpoint validato con @Valid  
- Niente credenziali hardcoded  

## 5. User Preferences
- Flutter: niente .withOpacity(); usare .withAlpha().  
```dart
color: Colors.blue.withAlpha((0.12 * 255).round());
```

## 6. Architecture (Backend)
Package root: `com.projectf`  
Directories: controller / service / repository / model(entity) / dto / config / security  
Principi:  
- Controller: validazione + delega  
- Service: business rules  
- Repository: accesso dati  
- DTO: disaccoppiamento API vs entity

## 7. Architecture (Frontend)
`lib/blocs`, `models`, `services` (Dio + interceptor JWT), `screens`, `widgets`  
- JWT in `flutter_secure_storage`  
- Interceptor aggiunge Authorization + gestisce 401

## 8. Testing Strategy
- Unit test: service isolato (mock repository).  
- Integration test: percorso end-to-end (controller → service → repository).  
- Creazione dati sempre via service (vedi 4.1).  
- Assert monetari su DTO con BigDecimal.  
- Evitare logica condizionale non testata.

## 9. Operational Checklist (Prima di ogni modifica)
1. Raccogli file e classi coinvolte (controller, DTO, service).  
2. Verifica se importi monetari sono toccati (applica mapping corretto).  
3. Controlla che il formato API resti invariato (o segnala).  
4. Rispetta separazione controller/service/repository.  
5. Aggiungi/aggiorna test se cambia business logic.  
6. Evita refactoring non richiesti.  
7. In caso di test falliti: analizza cause, proponi fix (senza applicarli prima di conferma).  
8. Chiedi conferma prima di scrivere file.  

## 10. Comment & Documentation Policy
- `// USER PREFERENCE:` scelte utente contro standard.  
- `// CUSTOM IMPLEMENTATION:` logica non ovvia o pattern ad hoc.  
- Non commentare codice banale, boilerplate, annotazioni standard.

## 11. Initiative & Scope Control
- Implementare solo quanto richiesto.  
- Per cambi multi-step con potenziale impatto, fermarsi e chiedere conferma.  
- Miglioramenti opzionali: proporre, non applicare.

## 12. Update Triggers
Aggiornare questo file se l’utente scrive:  
- “direttiva:” / “directive:”  
- “add this to instructions”  
- Aggiunge regola permanente esplicita  

## 13. How to Extend
Nuova regola: classificarla in Hard Directives (se vincolo tecnico) o User Preferences (se preferenza). Aggiungere sezione/bullet, evitare duplicazioni, mantenere stile conciso.

## 14. Reference Snippets
Monetary mapping (vedi 4.2) ripetuto per immediatezza:  
```java
dto.setAmount(model.getAmount() != null ? BigDecimal.valueOf(model.getAmount()) : null);
model.setAmount(dto.getAmount() != null ? dto.getAmount().doubleValue() : null);
```
Flutter alpha:  
```dart
color: Colors.blue.withAlpha((0.12 * 255).round());
```

FINE DOCUMENTO
