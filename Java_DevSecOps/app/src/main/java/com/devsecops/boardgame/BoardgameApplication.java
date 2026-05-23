package com.devsecops.boardgame;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * ==============================================================================
 * Boardgame Application — Main Entry Point
 * ==============================================================================
 * This is the Spring Boot main class that bootstraps the application.
 * 
 * The @SpringBootApplication annotation combines:
 *   - @Configuration:      Marks this class as a source of bean definitions
 *   - @EnableAutoConfiguration: Enables Spring Boot auto-configuration
 *   - @ComponentScan:      Scans for @Controller, @Service, etc. in this package
 * 
 * When deployed to Kubernetes, this application:
 *   - Starts an embedded Tomcat server on port 8080
 *   - Exposes REST API endpoints (/api/health, /api/info)
 *   - Provides Actuator endpoints for K8s health probes (/actuator/health)
 *   - Runs as a non-root user inside the Docker container for security
 * ==============================================================================
 */
@SpringBootApplication
public class BoardgameApplication {

    /**
     * Application entry point.
     * Spring Boot initializes the application context, starts the embedded
     * Tomcat server, and begins accepting HTTP requests on port 8080.
     *
     * @param args command-line arguments (passed via Docker CMD or K8s args)
     */
    public static void main(String[] args) {
        SpringApplication.run(BoardgameApplication.class, args);
    }
}
