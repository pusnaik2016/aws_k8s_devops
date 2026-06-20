# ============================================================================
# Imaging Service — Multi-stage Dockerfile (extra image processing libs)
# ============================================================================

FROM eclipse-temurin:21-jdk-jammy@sha256:4f5e74bf7a0d6e4c9a3e44b1e8f7c0a2b1d3e5f6a7b8c9d0e1f2a3b4c5d6e7f AS builder
WORKDIR /app
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline -B
COPY src src
RUN ./mvnw package -DskipTests -B && \
    java -Djarmode=layertools -jar target/*.jar extract

FROM eclipse-temurin:21-jre-jammy@sha256:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b
RUN groupadd -r healthcloud && \
    useradd -r -g healthcloud -d /app -s /sbin/nologin healthcloud && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl libopenjp2-7 && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./
RUN chown -R healthcloud:healthcloud /app
USER healthcloud
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-Dspring.profiles.active=kubernetes", \
    "org.springframework.boot.loader.launch.JarLauncher"]
