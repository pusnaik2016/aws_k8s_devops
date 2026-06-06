package com.devsecops.boardgame.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * ==============================================================================
 * Health Controller — Application Health and Info Endpoints
 * ==============================================================================
 * Provides custom REST endpoints for application health monitoring and
 * information retrieval. These endpoints complement the Spring Boot Actuator
 * health endpoint and are used in the DevSecOps pipeline:
 * 
 *   - /api/health  → Used by Jenkins smoke tests to verify the container starts
 *                     and responds correctly after Docker build
 *   - /api/info    → Returns application metadata (version, build time, etc.)
 * 
 * Kubernetes uses the Actuator endpoint (/actuator/health) for pod probes,
 * while these custom endpoints provide richer application-level information.
 * ==============================================================================
 */
@RestController
@RequestMapping("/api")
public class HealthController {

    /** Application name injected from application.properties */
    @Value("${app.name:boardgame-app}")
    private String appName;

    /** Application version injected from application.properties */
    @Value("${app.version:1.0.0}")
    private String appVersion;

    /** Application environment injected from application.properties */
    @Value("${app.environment:development}")
    private String environment;

    /**
     * Custom health check endpoint.
     * 
     * Returns a simple JSON response indicating the application is running.
     * This endpoint is called by the Jenkins CI pipeline during the smoke test
     * stage to validate that the newly built Docker container starts successfully
     * and can handle HTTP requests.
     * 
     * Example response:
     *   { "status": "UP", "application": "boardgame-app", "timestamp": "..." }
     *
     * @return ResponseEntity with health status, application name, and timestamp
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "UP");
        response.put("application", appName);
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }

    /**
     * Application information endpoint.
     * 
     * Returns metadata about the running application including version,
     * environment, Java runtime version, and system memory information.
     * Useful for verifying the correct version is deployed after ArgoCD sync.
     * 
     * Example response:
     *   {
     *     "application": "boardgame-app",
     *     "version": "1.0.0",
     *     "environment": "development",
     *     "java_version": "17.0.x",
     *     "total_memory_mb": 512,
     *     "free_memory_mb": 256,
     *     "timestamp": "2024-01-15T10:30:00Z"
     *   }
     *
     * @return ResponseEntity with application metadata
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("application", appName);
        response.put("version", appVersion);
        response.put("environment", environment);
        response.put("java_version", System.getProperty("java.version"));
        response.put("total_memory_mb", Runtime.getRuntime().totalMemory() / (1024 * 1024));
        response.put("free_memory_mb", Runtime.getRuntime().freeMemory() / (1024 * 1024));
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }
}
