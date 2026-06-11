package com.medcloud.patient;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * MedCloud Patient Service — Healthcare Records Management.
 * Deployed on Azure AKS. Connects to Cosmos DB (MongoDB API),
 * Azure Key Vault (encryption keys), and Azure OpenAI (clinical NLP).
 * Compliance: HIPAA (PHI), GDPR (EU patient data).
 */
@SpringBootApplication
public class PatientApplication {
    public static void main(String[] args) {
        SpringApplication.run(PatientApplication.class, args);
    }
}
