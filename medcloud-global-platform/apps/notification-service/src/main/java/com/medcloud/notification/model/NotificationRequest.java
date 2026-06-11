package com.medcloud.notification.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationRequest {

    @NotNull
    private NotificationType type;

    @NotBlank
    private String recipientId;

    private String recipientEmail;
    private String recipientPhone;

    @NotBlank
    private String subject;

    @NotBlank
    private String body;

    private String templateId;
    private java.util.Map<String, String> templateParams;

    public enum NotificationType {
        ORDER_CONFIRMATION,
        ORDER_SHIPPED,
        PRESCRIPTION_READY,
        APPOINTMENT_REMINDER,
        SECURITY_ALERT,
        PAYMENT_RECEIVED
    }
}
