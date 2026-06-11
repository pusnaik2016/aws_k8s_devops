package com.medcloud.notification.model;

import lombok.*;
import java.time.Instant;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationResponse {
    private String messageId;
    private String channel;    // EMAIL, SMS, PUSH
    private String status;     // SENT, QUEUED, FAILED
    private Instant sentAt;
}
