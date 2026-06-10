# ─────────────────────────────────────────────────────────────────────────────
# Patient Service — Dockerfile (Java 21 / Spring Boot on Azure AKS)
# ─────────────────────────────────────────────────────────────────────────────

FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B
COPY src ./src
RUN ./mvnw clean package -DskipTests -B && \
    cp target/*.jar app.jar && \
    java -Djarmode=layertools -jar app.jar extract --destination extracted

FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S medcloud && adduser -S medcloud -G medcloud
RUN apk --no-cache add curl && rm -rf /var/cache/apk/*
WORKDIR /app
COPY --from=build /app/extracted/dependencies/ ./
COPY --from=build /app/extracted/spring-boot-loader/ ./
COPY --from=build /app/extracted/snapshot-dependencies/ ./
COPY --from=build /app/extracted/application/ ./
USER medcloud:medcloud
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.title="MedCloud Patient Service" \
      org.opencontainers.image.description="Healthcare Records — Cosmos DB + Azure OpenAI" \
      compliance.hipaa="true"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/urandom", "-Dspring.profiles.active=production", \
  "org.springframework.boot.loader.launch.JarLauncher"]
