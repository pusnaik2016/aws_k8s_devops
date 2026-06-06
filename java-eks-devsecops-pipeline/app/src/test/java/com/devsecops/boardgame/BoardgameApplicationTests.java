package com.devsecops.boardgame;

import com.devsecops.boardgame.controller.HealthController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * ==============================================================================
 * Boardgame Application Unit Tests
 * ==============================================================================
 * Tests the REST API endpoints of the Boardgame application.
 * These tests run during the Jenkins CI pipeline 'Unit Tests' stage
 * and generate JUnit XML reports for Jenkins test result visualization.
 * 
 * Test coverage data is collected by JaCoCo and reported to SonarQube
 * to enforce the quality gate (minimum coverage threshold).
 * 
 * Using @WebMvcTest to test only the web layer (controller) without
 * starting the full application context — this makes tests faster.
 * ==============================================================================
 */
@WebMvcTest(HealthController.class)
class BoardgameApplicationTests {

    /** MockMvc provides a way to test Spring MVC controllers without starting a server */
    @Autowired
    private MockMvc mockMvc;

    /**
     * Verifies the /api/health endpoint returns HTTP 200 with status "UP".
     * This is the same endpoint called during the Jenkins smoke test stage
     * to validate the Docker container starts correctly.
     */
    @Test
    void healthEndpointReturnsUp() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.application").value("boardgame-app"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    /**
     * Verifies the /api/info endpoint returns HTTP 200 with app metadata.
     * Checks that version, environment, and Java version fields are present
     * in the response body.
     */
    @Test
    void infoEndpointReturnsAppMetadata() throws Exception {
        mockMvc.perform(get("/api/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.application").value("boardgame-app"))
                .andExpect(jsonPath("$.version").value("1.0.0"))
                .andExpect(jsonPath("$.environment").exists())
                .andExpect(jsonPath("$.java_version").exists())
                .andExpect(jsonPath("$.total_memory_mb").exists())
                .andExpect(jsonPath("$.free_memory_mb").exists())
                .andExpect(jsonPath("$.timestamp").exists());
    }

    /**
     * Verifies the /api/health endpoint returns the correct Content-Type header.
     * Ensures the response is JSON, which is required for both Jenkins smoke
     * tests and Kubernetes health probes to parse the response correctly.
     */
    @Test
    void healthEndpointReturnsJson() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/json"));
    }
}
