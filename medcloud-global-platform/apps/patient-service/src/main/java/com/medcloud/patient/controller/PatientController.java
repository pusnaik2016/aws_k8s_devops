package com.medcloud.patient.controller;

import com.medcloud.patient.model.Patient;
import com.medcloud.patient.service.PatientService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/patients")
@RequiredArgsConstructor
@Slf4j
public class PatientController {

    private final PatientService patientService;

    @PostMapping
    public ResponseEntity<Patient> createPatient(@Valid @RequestBody Patient patient) {
        log.info("Creating patient record (PHI — audit logged)");
        Patient created = patientService.createPatient(patient);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping("/{patientId}")
    public ResponseEntity<Patient> getPatient(@PathVariable String patientId) {
        return patientService.findById(patientId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/region/{region}")
    public ResponseEntity<List<Patient>> getPatientsByRegion(@PathVariable String region) {
        return ResponseEntity.ok(patientService.findByRegion(region));
    }

    @PutMapping("/{patientId}/consent")
    public ResponseEntity<Patient> updateConsent(
            @PathVariable String patientId,
            @RequestBody Patient.ConsentFlags consent) {
        return patientService.updateConsent(patientId, consent)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{patientId}")
    public ResponseEntity<Void> deletePatient(@PathVariable String patientId) {
        // GDPR Article 17 — Right to Erasure
        log.warn("GDPR erasure request: patientId={}", patientId);
        patientService.requestErasure(patientId);
        return ResponseEntity.accepted().build();
    }
}
