package com.medcloud.notification.controller;

import com.medcloud.notification.model.NotificationRequest;
import com.medcloud.notification.model.NotificationResponse;
import com.medcloud.notification.service.NotificationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
@Slf4j
public class NotificationController {

    private final NotificationService notificationService;

    @PostMapping("/email")
    public ResponseEntity<NotificationResponse> sendEmail(@Valid @RequestBody NotificationRequest request) {
        log.info("Sending email notification: type={}, recipient={}", request.getType(), request.getRecipientId());
        return ResponseEntity.ok(notificationService.sendEmail(request));
    }

    @PostMapping("/sms")
    public ResponseEntity<NotificationResponse> sendSms(@Valid @RequestBody NotificationRequest request) {
        log.info("Sending SMS notification: type={}, recipient={}", request.getType(), request.getRecipientId());
        return ResponseEntity.ok(notificationService.sendSms(request));
    }

    @PostMapping("/push")
    public ResponseEntity<NotificationResponse> sendPush(@Valid @RequestBody NotificationRequest request) {
        log.info("Sending push notification: type={}", request.getType());
        return ResponseEntity.ok(notificationService.sendPush(request));
    }
}
