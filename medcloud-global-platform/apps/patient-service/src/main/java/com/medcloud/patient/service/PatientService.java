package com.medcloud.patient.service;

import com.medcloud.patient.model.Patient;
import com.medcloud.patient.repository.PatientRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class PatientService {

    private final PatientRepository patientRepository;

    public Patient createPatient(Patient patient) {
        patient.setCreatedAt(Instant.now());
        patient.setUpdatedAt(Instant.now());
        return patientRepository.save(patient);
    }

    public Optional<Patient> findById(String patientId) {
        return patientRepository.findByPatientId(patientId);
    }

    public List<Patient> findByRegion(String region) {
        return patientRepository.findByRegion(region);
    }

    public Optional<Patient> updateConsent(String patientId, Patient.ConsentFlags consent) {
        return patientRepository.findByPatientId(patientId)
                .map(patient -> {
                    consent.setConsentDate(Instant.now());
                    patient.setConsent(consent);
                    patient.setUpdatedAt(Instant.now());
                    log.info("Consent updated for patient: {}", patientId);
                    return patientRepository.save(patient);
                });
    }

    /**
     * GDPR Article 17 — marks patient for erasure.
     * Actual deletion happens via scheduled batch job to ensure
     * all cross-cloud references are cleaned up.
     */
    public void requestErasure(String patientId) {
        patientRepository.findByPatientId(patientId)
                .ifPresent(patient -> {
                    patient.setGdprDeletionRequestedAt(Instant.now());
                    patient.setUpdatedAt(Instant.now());
                    patientRepository.save(patient);
                    log.warn("GDPR erasure requested for patient: {}", patientId);
                });
    }
}
