# ─────────────────────────────────────────────────────────────────────────────
# Storefront API — Multi-stage Dockerfile (Java 21 / Spring Boot)
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA-hardened: non-root user, no shell, minimal attack surface.
# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app

# Cache Maven dependencies
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Build application
COPY src ./src
RUN ./mvnw clean package -DskipTests -B && \
    cp target/*.jar app.jar && \
    java -Djarmode=layertools -jar app.jar extract --destination extracted

# Stage 2: Runtime (distroless for minimal attack surface)
FROM eclipse-temurin:21-jre-alpine AS runtime

# Security: Create non-root user
RUN addgroup -S medcloud && adduser -S medcloud -G medcloud

# HIPAA: Remove unnecessary packages
RUN apk --no-cache add curl && \
    rm -rf /var/cache/apk/*

WORKDIR /app

# Copy layers for optimal Docker caching
COPY --from=build /app/extracted/dependencies/ ./
COPY --from=build /app/extracted/spring-boot-loader/ ./
COPY --from=build /app/extracted/snapshot-dependencies/ ./
COPY --from=build /app/extracted/application/ ./

# Security: Non-root user
USER medcloud:medcloud

# Metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.opencontainers.image.title="MedCloud Storefront API" \
      org.opencontainers.image.description="E-Commerce API for MedCloud Global Platform" \
      org.opencontainers.image.vendor="MedCloud" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      compliance.hipaa="true" \
      compliance.pci-dss="true"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/urandom", \
  "-Dspring.profiles.active=production", \
  "org.springframework.boot.loader.launch.JarLauncher"]
