package com.medcloud.order.service;

import com.medcloud.order.model.Order;
import com.medcloud.order.model.OrderStatus;
import com.medcloud.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;

    @Transactional
    public Order createOrder(Order order, String idempotencyKey) {
        // Idempotency check — return existing order if same key
        Optional<Order> existing = orderRepository.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            log.info("Duplicate order detected: idempotencyKey={}", idempotencyKey);
            return existing.get();
        }

        order.setIdempotencyKey(idempotencyKey);
        order.setStatus(OrderStatus.PENDING);
        Order saved = orderRepository.save(order);
        log.info("Order created: id={}, amount={}", saved.getOrderId(), saved.getTotalAmount());

        // TODO: Publish OrderCreated event to SNS for cross-cloud saga
        // snsClient.publish(topic, OrderCreatedEvent.from(saved));

        return saved;
    }

    public Optional<Order> findById(UUID orderId) {
        return orderRepository.findById(orderId);
    }

    public Page<Order> findByCustomerId(UUID customerId, Pageable pageable) {
        return orderRepository.findByCustomerIdOrderByCreatedAtDesc(customerId, pageable);
    }

    @Transactional
    public Optional<Order> updateStatus(UUID orderId, OrderStatus newStatus) {
        return orderRepository.findById(orderId)
                .map(order -> {
                    OrderStatus oldStatus = order.getStatus();
                    order.setStatus(newStatus);
                    log.info("Order status updated: id={}, {} → {}", orderId, oldStatus, newStatus);
                    return orderRepository.save(order);
                });
    }

    @Transactional
    public Optional<Order> cancelOrder(UUID orderId) {
        return orderRepository.findById(orderId)
                .filter(o -> o.getStatus() == OrderStatus.PENDING || o.getStatus() == OrderStatus.CONFIRMED)
                .map(order -> {
                    order.setStatus(OrderStatus.CANCELLED);
                    log.info("Order cancelled: id={}", orderId);
                    return orderRepository.save(order);
                });
    }
}
