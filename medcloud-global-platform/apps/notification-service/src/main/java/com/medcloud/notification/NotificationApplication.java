package com.medcloud.notification;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * MedCloud Notification Service — Multi-Channel Alerts.
 * Sends order confirmations, prescription alerts, appointment reminders
 * via SNS (SMS), SES (email), and push notifications.
 */
@SpringBootApplication
@EnableAsync
public class NotificationApplication {
    public static void main(String[] args) {
        SpringApplication.run(NotificationApplication.class, args);
    }
}
