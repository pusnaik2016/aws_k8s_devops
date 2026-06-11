package com.medcloud.storefront;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * MedCloud Storefront API — E-Commerce Frontend Service.
 *
 * Deployed on AWS EKS. Serves product catalog, shopping cart,
 * and checkout flows. Connects to Aurora PostgreSQL, DynamoDB
 * (sessions/carts), and ElastiCache Redis (caching).
 *
 * Compliance: PCI-DSS (payment data tokenization)
 */
@SpringBootApplication
@EnableAsync
public class StorefrontApplication {

    public static void main(String[] args) {
        SpringApplication.run(StorefrontApplication.class, args);
    }
}
