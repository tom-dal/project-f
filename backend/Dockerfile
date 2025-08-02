# Multi-stage build per ottimizzare le dimensioni dell'immagine

# Stage 1: Build
FROM eclipse-temurin:17-jdk AS build

# Installa Maven
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Imposta la directory di lavoro
WORKDIR /app

# Copia i file di configurazione Maven
COPY pom.xml .
COPY mvnw .
COPY mvnw.cmd .
COPY .mvn .mvn

# Scarica le dipendenze (questo step viene cachato se il pom.xml non cambia)
RUN mvn dependency:go-offline -B

# Copia il codice sorgente
COPY src ./src

# Compila l'applicazione
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:17-jre

# Installa curl per healthcheck e client database per debugging (opzionale)
RUN apt-get update && apt-get install -y curl postgresql-client && rm -rf /var/lib/apt/lists/*

# Crea un utente non-root per sicurezza
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Imposta la directory di lavoro
WORKDIR /app

# Copia il JAR dall'immagine di build
COPY --from=build /app/target/project-f-backend-1.0.0.jar app.jar

# Crea directory per i log e cambia ownership
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

# Cambia all'utente non-root
USER appuser

# Espone la porta dell'applicazione (default Spring Boot: 8080)
EXPOSE 8080

# Variabili d'ambiente per database esterno (valori di default - NON per produzione)
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SPRING_PROFILES_ACTIVE=production
ENV DB_HOST=localhost
ENV DB_PORT=5432
ENV DB_NAME=debtcollection
ENV DB_USERNAME=dbuser
# NOTA: DB_PASSWORD deve essere passata SOLO come variabile d'ambiente durante il run del container
# NON memorizzare mai password nell'immagine Docker

# Comando per avviare l'applicazione con configurazione database esterna
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME} -Dspring.datasource.username=${DB_USERNAME} -Dspring.datasource.password=${DB_PASSWORD:-defaultpass} -jar app.jar"]

# Healthcheck per verificare lo stato dell'applicazione
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
