# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app

# Download dependencies first (cached until pom.xml changes)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Build the layered fat JAR (skipping tests — run tests in CI)
COPY src ./src
RUN mvn package -DskipTests -q

# ── Stage 2: Extract Spring Boot Layers ─────────────────────────────────────
# Splits the JAR into layers ordered by change frequency:
#   dependencies → spring-boot-loader → snapshot-dependencies → application
FROM eclipse-temurin:17-jre-alpine AS extractor
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ── Stage 3: Production Runtime ─────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app

# Non-root user for security
RUN addgroup -S bodhganga && adduser -S bodhganga -G bodhganga

# Copy layers least-to-most frequently changed (maximises Docker cache hits)
COPY --from=extractor --chown=bodhganga:bodhganga /app/dependencies/ ./
COPY --from=extractor --chown=bodhganga:bodhganga /app/spring-boot-loader/ ./
COPY --from=extractor --chown=bodhganga:bodhganga /app/snapshot-dependencies/ ./
COPY --from=extractor --chown=bodhganga:bodhganga /app/application/ ./

ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+ExitOnOutOfMemoryError \
               -Djava.security.egd=file:/dev/./urandom"

# BodhGanga app port: 9090 (app + management on same port)
EXPOSE 9090

USER bodhganga

# Health check for docker-compose / Docker Swarm environments
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:9090/actuator/health/liveness || exit 1

ENTRYPOINT ["sh", "-c", \
  "java $JAVA_OPTS \
   -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-prod} \
   org.springframework.boot.loader.launch.JarLauncher"]
