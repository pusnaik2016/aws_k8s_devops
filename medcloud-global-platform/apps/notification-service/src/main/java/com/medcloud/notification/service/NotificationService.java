package com.medcloud.notification.service;

import com.medcloud.notification.model.NotificationRequest;
import com.medcloud.notification.model.NotificationResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;
import software.amazon.awssdk.services.sns.model.PublishResponse;

import java.time.Instant;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private final SesClient sesClient;
    private final SnsClient snsClient;

    /**
     * Send email via AWS SES.
     */
    public NotificationResponse sendEmail(NotificationRequest request) {
        try {
            SendEmailRequest emailRequest = SendEmailRequest.builder()
                    .source("noreply@medcloud.example.com")
                    .destination(Destination.builder()
                            .toAddresses(request.getRecipientEmail())
                            .build())
                    .message(Message.builder()
                            .subject(Content.builder().data(request.getSubject()).build())
                            .body(Body.builder()
                                    .html(Content.builder().data(request.getBody()).build())
                                    .build())
                            .build())
                    .build();

            SendEmailResponse response = sesClient.sendEmail(emailRequest);
            log.info("Email sent: messageId={}, recipient={}", response.messageId(), request.getRecipientEmail());

            return NotificationResponse.builder()
                    .messageId(response.messageId())
                    .channel("EMAIL")
                    .status("SENT")
                    .sentAt(Instant.now())
                    .build();
        } catch (Exception e) {
            log.error("Email send failed: recipient={}, error={}", request.getRecipientEmail(), e.getMessage());
            return NotificationResponse.builder()
                    .channel("EMAIL")
                    .status("FAILED")
                    .sentAt(Instant.now())
                    .build();
        }
    }

    /**
     * Send SMS via AWS SNS.
     */
    public NotificationResponse sendSms(NotificationRequest request) {
        try {
            PublishRequest smsRequest = PublishRequest.builder()
                    .phoneNumber(request.getRecipientPhone())
                    .message(request.getBody())
                    .build();

            PublishResponse response = snsClient.publish(smsRequest);
            log.info("SMS sent: messageId={}, phone={}", response.messageId(), request.getRecipientPhone());

            return NotificationResponse.builder()
                    .messageId(response.messageId())
                    .channel("SMS")
                    .status("SENT")
                    .sentAt(Instant.now())
                    .build();
        } catch (Exception e) {
            log.error("SMS send failed: error={}", e.getMessage());
            return NotificationResponse.builder()
                    .channel("SMS")
                    .status("FAILED")
                    .sentAt(Instant.now())
                    .build();
        }
    }

    /**
     * Send push notification via SNS Platform Application.
     */
    @Async
    public NotificationResponse sendPush(NotificationRequest request) {
        try {
            PublishRequest pushRequest = PublishRequest.builder()
                    .targetArn(request.getRecipientId())
                    .message(request.getBody())
                    .subject(request.getSubject())
                    .build();

            PublishResponse response = snsClient.publish(pushRequest);
            log.info("Push notification sent: messageId={}", response.messageId());

            return NotificationResponse.builder()
                    .messageId(response.messageId())
                    .channel("PUSH")
                    .status("SENT")
                    .sentAt(Instant.now())
                    .build();
        } catch (Exception e) {
            log.error("Push send failed: error={}", e.getMessage());
            return NotificationResponse.builder()
                    .channel("PUSH")
                    .status("FAILED")
                    .sentAt(Instant.now())
                    .build();
        }
    }
}
