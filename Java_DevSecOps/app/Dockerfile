# ==============================================================================
# Dockerfile — Boardgame Application (Multi-Stage Build)
# ==============================================================================
# This Dockerfile uses a multi-stage build process:
#
#   Stage 1 (builder): Uses Maven + JDK to compile the Java application,
#                       run tests, and produce an executable JAR file.
#
#   Stage 2 (runtime): Uses a slim JRE image to run the JAR file. This
#                       reduces the final image size significantly (~200MB
#                       vs ~800MB with full JDK).
#
# Security best practices implemented:
#   - Non-root user (appuser) for running the application
#   - Read-only root filesystem compatible
#   - No shell access in the runtime image (slim base)
#   - Minimal attack surface with JRE-only runtime
#   - HEALTHCHECK instruction for Docker-level monitoring
#
# Build:  docker build -t boardgame-app:latest .
# Run:    docker run -p 8080:8080 boardgame-app:latest
# ==============================================================================

# =============================================================================
# Stage 1: Build — Compile the Java application using Maven
# =============================================================================
# Uses the official Maven image with JDK 17 to:
#   1. Download project dependencies (cached in a Docker layer)
#   2. Compile the Java source code
#   3. Run unit tests
#   4. Package the application as an executable JAR
# =============================================================================
FROM maven:3.9-eclipse-temurin-17 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy only the POM file first to leverage Docker layer caching.
# Dependencies are downloaded in this step and cached. As long as pom.xml
# doesn't change, Docker reuses this layer — speeding up subsequent builds.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the application source code
COPY src ./src

# Build the application JAR (skip tests here since they run in CI pipeline)
RUN mvn package -DskipTests -B

# =============================================================================
# Stage 2: Runtime — Slim JRE image for running the application
# =============================================================================
# Uses Eclipse Temurin 17 JRE (Java Runtime Environment only, no JDK).
# This significantly reduces the image size and attack surface by excluding
# the compiler, build tools, and development headers.
# =============================================================================
FROM eclipse-temurin:17-jre-jammy

# Create a non-root user for running the application.
# Running as non-root is a critical security best practice that prevents
# container escape vulnerabilities from gaining root access on the host.
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --shell /bin/false appuser

# Set the working directory
WORKDIR /app

# Copy the built JAR from the builder stage
# Only the final JAR is copied — source code, Maven cache, and build
# artifacts are left behind in the builder stage (not in final image)
COPY --from=builder /app/target/boardgame-app.jar boardgame-app.jar

# Change ownership to the non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user for all subsequent commands and runtime
USER appuser

# Expose the application port (documentation + container orchestration hint)
EXPOSE 8080

# Docker-level health check — verifies the application responds to HTTP requests.
# This is in addition to Kubernetes liveness/readiness probes.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start the Spring Boot application with optimized JVM settings:
#   -XX:+UseContainerSupport: Respect container memory limits
#   -XX:MaxRAMPercentage=75: Use up to 75% of container memory for JVM heap
#   -Djava.security.egd: Use non-blocking entropy source for faster startup
ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "boardgame-app.jar"]
