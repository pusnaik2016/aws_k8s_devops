package com.medcloud.patient.model;

import lombok.*;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.List;

/**
 * Patient document — stored in Cosmos DB (MongoDB API).
 * All PHI fields are encrypted (AES-256) before storage.
 */
@Document(collection = "patients")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Patient {

    @Id
    private String id;

    @Indexed(unique = true)
    private String patientId;  // Business ID: PAT-2024-XXXXX

    @Indexed
    private String region;     // Shard key for Cosmos DB

    private Demographics demographics;
    private Contact contact;
    private Insurance insurance;
    private ConsentFlags consent;
    private List<String> linkedOrders;      // Cross-cloud refs to AWS order IDs
    private List<String> medicalRecordRefs;

    private Instant createdAt;
    private Instant updatedAt;
    private Instant gdprDeletionRequestedAt;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Demographics {
        private String firstNameEncrypted;   // AES-256 encrypted
        private String lastNameEncrypted;    // AES-256 encrypted
        private String dateOfBirthEncrypted; // AES-256 encrypted
        private String gender;
        private String bloodType;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Contact {
        private String emailHash;          // SHA-256 hash for lookup
        private String phoneEncrypted;     // AES-256 encrypted
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Insurance {
        private String provider;
        private String policyNumberEncrypted;
        private String groupNumberEncrypted;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ConsentFlags {
        private boolean dataProcessing;
        private boolean dataSharingAnalytics;
        private boolean marketing;
        private Instant consentDate;
        private boolean gdprApplicable;
    }
}
