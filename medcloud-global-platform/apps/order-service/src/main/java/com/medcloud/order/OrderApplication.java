package com.medcloud.order;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * MedCloud Order Service — Transaction Processing.
 * Handles order creation, payment orchestration (Stripe/Adyen tokenization),
 * inventory management, and prescription order linking.
 * Compliance: PCI-DSS (payment tokens, no raw card data stored).
 */
@SpringBootApplication
public class OrderApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderApplication.class, args);
    }
}
