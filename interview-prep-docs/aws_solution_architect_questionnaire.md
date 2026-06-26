# AWS Solution Architect — Interview Questionnaire & Answers

> **Role:** AWS Solution Architect | **Experience:** 12–17 years | **Coding:** Mandatory
> **Locations:** Kolkata, Kochi, Mumbai, Bangalore, Hyderabad

---

## Table of Contents

1. [Topic 1 — Cloud Architecture Design (20%)](#topic-1--cloud-architecture-design-20)
2. [Topic 2 — Serverless &amp; Event-Driven Architecture (20%)](#topic-2--serverless--event-driven-architecture-20)
3. [Topic 3 — Application Development &amp; Integration (20%)](#topic-3--application-development--integration-20)
4. [Topic 4 — Data Stores &amp; Search Platforms (15%)](#topic-4--data-stores--search-platforms-15)
5. [Topic 5 — DevOps, IaC &amp; Container Management (15%)](#topic-5--devops-iac--container-management-15)
6. [Topic 6 — Monitoring, Logging &amp; Observability (10%)](#topic-6--monitoring-logging--observability-10)
7. [Bonus — Scenario-Based / System Design Questions](#bonus--scenario-based--system-design-questions)
8. [Soft Skills &amp; Behavioral Questions](#soft-skills--behavioral-questions)

---

## Topic 1 — Cloud Architecture Design (20%)

*Skill to design scalable, resilient, and maintainable cloud architectures in AWS.*

---

### Q1.1: What are the six pillars of the AWS Well-Architected Framework? Explain each briefly

**Answer:**

| Pillar                           | Description                                                                                                                                              |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Operational Excellence** | Run and monitor systems to deliver business value; continuously improve processes and procedures. Includes IaC, observability, and runbook automation.   |
| **Security**               | Protect data, systems, and assets. Implement identity management, detection controls, infrastructure protection, data protection, and incident response. |
| **Reliability**            | Ensure a workload performs its intended function correctly and consistently. Covers fault tolerance, auto-recovery, and scaling.                         |
| **Performance Efficiency** | Use computing resources efficiently. Select the right resource types and sizes, monitor performance, and maintain efficiency as business needs evolve.   |
| **Cost Optimization**      | Avoid unnecessary costs. Understand spending, select the most cost-effective resources, scale to meet demand without overspending.                       |
| **Sustainability**         | Minimize environmental impact. Reduce energy consumption and increase efficiency through right-sizing, managed services, and workload optimization.      |

---

### Q1.2: How would you design a multi-tier web application on AWS for high availability and fault tolerance?

**Answer:**

```
                        ┌─────────────┐
                        │   Route 53  │  (DNS + Health Checks)
                        └──────┬──────┘
                               │
                     ┌─────────▼─────────┐
                     │   CloudFront CDN  │  (Edge caching, SSL termination)
                     └─────────┬─────────┘
                               │
                     ┌─────────▼─────────┐
                     │       ALB         │  (Application Load Balancer, multi-AZ)
                     └────┬─────────┬────┘
                          │         │
                ┌─────────▼──┐  ┌──▼─────────┐
                │  EC2 / ECS │  │  EC2 / ECS │   (Auto Scaling Group, 2+ AZs)
                │   (AZ-1)   │  │   (AZ-2)   │
                └─────────┬──┘  └──┬─────────┘
                          │        │
                     ┌────▼────────▼────┐
                     │  Amazon RDS      │  (Multi-AZ, Read Replicas)
                     │  / Aurora        │
                     └──────────────────┘
```

**Key design decisions:**

- **Multi-AZ deployment** for every tier — eliminates single points of failure.
- **Auto Scaling Groups** — horizontal scaling based on CPU/request metrics.
- **ALB with health checks** — automatically routes traffic away from unhealthy instances.
- **RDS Multi-AZ** — synchronous standby with automatic failover (< 60s).
- **CloudFront** — reduces latency and offloads origin.
- **Route 53** — DNS failover with health checks for regional disaster recovery.
- **S3** — for static assets, with versioning and cross-region replication for DR.
- **ElastiCache (Redis/Memcached)** — caching layer to reduce DB load.

---

### Q1.3: What is the difference between horizontal and vertical scaling? When would you choose each on AWS?

**Answer:**

| Aspect                | Vertical Scaling (Scale Up)                            | Horizontal Scaling (Scale Out)                  |
| --------------------- | ------------------------------------------------------ | ----------------------------------------------- |
| **Mechanism**   | Increase instance size (e.g., t3.medium → c5.4xlarge) | Add more instances behind a load balancer       |
| **Downtime**    | Typically requires restart                             | Zero downtime (new instances added dynamically) |
| **Upper Limit** | Bounded by the largest instance type                   | Virtually unlimited                             |
| **Cost Model**  | Non-linear cost increase                               | Linear cost increase                            |
| **Best For**    | Legacy monoliths, databases that can't shard easily    | Stateless microservices, web frontends          |

**AWS services for horizontal scaling:**

- **Auto Scaling Groups** (EC2)
- **ECS Service Auto Scaling** (containers)
- **DynamoDB Auto Scaling** (database reads/writes)
- **Aurora Auto Scaling** (read replicas)

**When to choose vertical:** When the application is stateful, tightly coupled, or the bottleneck is single-threaded processing (e.g., a legacy RDBMS that doesn't support sharding).

---

### Q1.4: Explain the difference between RPO and RTO. How do you design for both on AWS?

**Answer:**

- **RPO (Recovery Point Objective):** Maximum acceptable data loss measured in time. "How much data can we afford to lose?"
- **RTO (Recovery Time Objective):** Maximum acceptable downtime. "How fast must we recover?"

| Strategy                           | RPO              | RTO        | AWS Implementation                                                | Cost     |
| ---------------------------------- | ---------------- | ---------- | ----------------------------------------------------------------- | -------- |
| **Backup & Restore**         | Hours            | Hours      | S3 snapshots, AMI backups                                         | 💰 Low   |
| **Pilot Light**              | Minutes          | 10–30 min | Minimal infrastructure running (DB replica), scale up on failover | 💰💰     |
| **Warm Standby**             | Seconds–Minutes | Minutes    | Scaled-down but fully functional copy in another region           | 💰💰💰   |
| **Multi-Site Active-Active** | Near Zero        | Near Zero  | Full production in 2+ regions with Route 53 failover              | 💰💰💰💰 |

**Key AWS services for DR:**

- **S3 Cross-Region Replication** (CRR)
- **Aurora Global Database** (< 1 second replication lag)
- **DynamoDB Global Tables**
- **Route 53 health checks + failover routing**
- **AWS Backup** for centralized backup policies

---

### Q1.5: How do you implement a Zero-Trust security model on AWS?

**Answer:**

Zero Trust = "Never trust, always verify." Every request is authenticated, authorized, and encrypted regardless of network location.

**Implementation layers:**

1. **Identity & Access Management:**

   - Enforce **least-privilege IAM policies** with condition keys.
   - Use **IAM Roles** (not long-lived keys) for services and cross-account access.
   - Enable **MFA** for all human users; enforce via IAM policy conditions.
   - Use **AWS SSO / IAM Identity Center** with IdP integration (Okta, Azure AD).
2. **Network:**

   - Use **VPC Endpoints (PrivateLink)** — traffic never traverses the public internet.
   - **Security Groups** as micro-segmentation (deny-all by default).
   - **NACLs** for subnet-level stateless filtering.
   - **AWS PrivateLink** for service-to-service communication.
3. **Data Protection:**

   - Encryption at rest (**KMS CMKs**) and in transit (**TLS 1.2+** everywhere).
   - **S3 bucket policies** with explicit deny on unencrypted uploads.
   - **Macie** for sensitive data discovery.
4. **Detection & Response:**

   - **GuardDuty** for threat detection.
   - **CloudTrail** for API audit logs.
   - **Config Rules** for continuous compliance.
   - **Security Hub** for centralized findings.
5. **Application Layer:**

   - **WAF** on ALB/CloudFront with managed rule groups.
   - **API Gateway** with authorizers (Lambda, Cognito, IAM).
   - Short-lived tokens (JWT) with scoped permissions.

---

### Q1.6: What design patterns do you apply when migrating a monolithic application to microservices on AWS?

**Answer:**

**Migration patterns (incremental, not "big bang"):**

1. **Strangler Fig Pattern:**

   - Gradually replace parts of the monolith with microservices.
   - Use **API Gateway** or **ALB path-based routing** to route specific paths to new services while the monolith handles the rest.
   - This is the most commonly recommended pattern.
2. **Anti-Corruption Layer (ACL):**

   - Place an adapter between old and new systems so microservices don't inherit the monolith's data model.
3. **Database-per-Service:**

   - Each microservice owns its data store. Use **event sourcing** or **CDC (Change Data Capture)** via **DynamoDB Streams** or **Debezium on MSK** to synchronize when needed.
4. **Saga Pattern:**

   - Manage distributed transactions across services using choreography (events via SNS/SQS) or orchestration (Step Functions).
5. **CQRS (Command Query Responsibility Segregation):**

   - Separate read and write models for services with complex query requirements.

**AWS services for microservices:**

- **ECS / EKS** — container orchestration
- **App Mesh** — service mesh for observability and traffic management
- **API Gateway** — unified API front door
- **SQS / SNS / EventBridge** — decoupled communication
- **Step Functions** — workflow orchestration
- **X-Ray** — distributed tracing

---

### Q1.7: What is the shared responsibility model in AWS? Provide examples

**Answer:**

| Layer                      | AWS Responsibility ("Security OF the Cloud") | Customer Responsibility ("Security IN the Cloud") |
| -------------------------- | -------------------------------------------- | ------------------------------------------------- |
| **Physical**         | Data center security, hardware, networking   | N/A                                               |
| **Compute**          | Hypervisor, host OS patching                 | Guest OS patching, AMI hardening                  |
| **Storage**          | S3 infrastructure durability (11 9's)        | S3 bucket policies, encryption, access controls   |
| **Network**          | Global backbone, AZ isolation                | Security Groups, NACLs, VPN/TLS config            |
| **IAM**              | IAM service availability                     | IAM policies, MFA enforcement, role design        |
| **Managed Services** | Patching RDS engine, Lambda runtime          | Database parameter groups, function code security |

> [!IMPORTANT]
> The responsibility shifts depending on the service model. With **EC2** (IaaS), the customer is responsible for the OS, middleware, and runtime. With **Lambda** (serverless), AWS manages everything except the function code and IAM configuration.

---

## Topic 2 — Serverless & Event-Driven Architecture (20%)

*Design, implement, and optimize event-driven and serverless architectures.*

---

### Q2.1: Explain the core components of a serverless architecture on AWS

**Answer:**

| Component               | AWS Service                           | Role                                                                     |
| ----------------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| **Compute**       | Lambda                                | Run code without provisioning servers; scales automatically to zero      |
| **API Layer**     | API Gateway (REST/HTTP/WebSocket)     | Expose Lambda as HTTP endpoints, handle auth, throttling, caching        |
| **Event Bus**     | EventBridge                           | Central event router for decoupled, event-driven communication           |
| **Messaging**     | SQS (queue), SNS (pub/sub)            | Asynchronous decoupling between producers and consumers                  |
| **Orchestration** | Step Functions                        | Coordinate multi-step workflows with built-in error handling and retries |
| **Storage**       | S3, DynamoDB                          | Object storage and serverless NoSQL database                             |
| **Auth**          | Cognito                               | User pools, identity federation, JWT token issuance                      |
| **Streaming**     | Kinesis Data Streams / MSK Serverless | Real-time data ingestion and processing                                  |

---

### Q2.2: How do you handle cold starts in AWS Lambda? What strategies reduce latency?

**Answer:**

**What is a cold start?**
When Lambda creates a new execution environment: downloads code, initializes runtime, runs init code. This adds 100ms–10s latency depending on runtime and package size.

**Mitigation strategies:**

1. **Provisioned Concurrency:**

   - Pre-warms a specified number of execution environments.
   - Eliminates cold starts entirely for those instances.
   - Use **Application Auto Scaling** to schedule or target-track provisioned concurrency.
2. **Reduce package size:**

   - Use layers for shared dependencies.
   - Tree-shake unused modules.
   - For Java: use **GraalVM native image** or **SnapStart** (available for Java 11/17).
3. **Lambda SnapStart (Java):**

   - Takes a snapshot of the initialized execution environment.
   - Restores from snapshot instead of re-initializing (reduces cold start from ~5s to ~200ms).
4. **Choose lightweight runtimes:**

   - Python, Node.js have faster cold starts than Java, .NET.
   - Consider custom runtimes (Rust, Go) for ultra-low latency.
5. **Keep functions warm (anti-pattern but sometimes necessary):**

   - Scheduled EventBridge rule to invoke the function periodically.
   - Not recommended — provisioned concurrency is the proper solution.
6. **Connection pooling outside the handler:**

   ```python
   # Initialize DB connection outside handler (reused across invocations)
   import boto3
   dynamodb = boto3.resource('dynamodb')
   table = dynamodb.Table('MyTable')

   def handler(event, context):
       # table is reused in warm invocations
       return table.get_item(Key={'id': event['id']})
   ```

---

### Q2.3: Compare SQS, SNS, and EventBridge. When would you use each?

**Answer:**

| Feature                 | SQS                           | SNS                           | EventBridge                                                      |
| ----------------------- | ----------------------------- | ----------------------------- | ---------------------------------------------------------------- |
| **Pattern**       | Point-to-point queue          | Pub/sub fan-out               | Event bus with rules-based routing                               |
| **Delivery**      | Pull (consumer polls)         | Push to subscribers           | Push to targets                                                  |
| **Ordering**      | FIFO queues support ordering  | FIFO topics support ordering  | Ordered within partition key                                     |
| **Filtering**     | No native filtering           | Message attribute filters     | Content-based filtering (JSON path)                              |
| **Targets**       | Single consumer (per message) | Lambda, SQS, HTTP, Email, SMS | 20+ targets: Lambda, SQS, Step Functions, API destinations, etc. |
| **Retry/DLQ**     | Built-in DLQ                  | DLQ via SQS subscription      | Built-in DLQ, retry policies                                     |
| **Schema**        | Unstructured                  | Unstructured                  | Schema Registry with discovery & validation                      |
| **Cross-account** | Yes                           | Yes                           | Yes (cross-account event bus)                                    |

**Decision guide:**

- **SQS** → Buffering/decoupling between producer-consumer, rate leveling, guaranteed at-least-once delivery.
- **SNS** → Fan-out to multiple subscribers, simple pub/sub.
- **EventBridge** → Complex event routing with content-based rules, SaaS integrations, schema evolution, cross-account event sharing.

**Common pattern — SNS + SQS fan-out:**

```
Producer → SNS Topic → SQS Queue A (Service A)
                     → SQS Queue B (Service B)
                     → Lambda (Service C)
```

This gives fan-out (SNS) with buffering/retry per consumer (SQS).

---

### Q2.4: Design an event-driven order processing system using serverless AWS services

**Answer:**

```
┌─────────┐     ┌──────────────┐     ┌──────────────┐
│  Client  │────▶│ API Gateway  │────▶│ Lambda       │
│  (React) │     │  (REST API)  │     │ (OrderCreate)│
└─────────┘     └──────────────┘     └──────┬───────┘
                                            │ Put order in DynamoDB
                                            │ Emit event
                                     ┌──────▼───────┐
                                     │  EventBridge  │
                                     │  (Order Bus)  │
                                     └──┬────┬────┬──┘
                          ┌────────────┘    │    └──────────────┐
                          │                 │                    │
                  ┌───────▼──────┐  ┌──────▼───────┐   ┌──────▼───────┐
                  │ SQS + Lambda │  │ SQS + Lambda │   │ SQS + Lambda │
                  │ (Payment)    │  │ (Inventory)  │   │ (Notification)│
                  └───────┬──────┘  └──────┬───────┘   └──────┬───────┘
                          │                │                    │
                          └────────────────┘                    │
                                   │                            │
                          ┌────────▼────────┐          ┌───────▼──────┐
                          │  Step Functions │          │     SES      │
                          │  (Saga/Retry)   │          │ (Email)      │
                          └─────────────────┘          └──────────────┘
```

**Key design decisions:**

- **DynamoDB Streams** trigger the event — ensures the event is tied to the database write (transactional outbox pattern).
- **EventBridge** routes events to multiple consumers based on `detail-type`.
- **SQS between EventBridge and Lambda** — adds buffering, retry with backoff, and DLQ per consumer.
- **Step Functions** orchestrates the saga for payment + inventory (compensating transactions on failure).
- **Idempotency** — use `orderId` as idempotency key in each Lambda to handle retries safely.

---

### Q2.5: What is the Lambda execution model? Explain concurrency, throttling, and reserved concurrency

**Answer:**

- **Execution model:** Each concurrent invocation runs in its own isolated execution environment (microVM via Firecracker). After the invocation, the environment is frozen and may be reused for the next invocation ("warm start").
- **Concurrency = number of in-flight invocations at any given time.**

| Concept                           | Description                                                                                                                                     |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Account concurrency**     | Default 1,000 per region (can be raised to 10,000+ via service quota request)                                                                   |
| **Reserved concurrency**    | Guarantees a fixed pool of concurrency for a specific function AND caps it at that number. Other functions cannot consume this pool.            |
| **Provisioned concurrency** | Pre-initializes a specified number of execution environments to eliminate cold starts. Does NOT cap maximum concurrency.                        |
| **Throttling**              | When concurrency limit is reached, additional invocations receive a`429 TooManyRequestsException` (synchronous) or are retried (asynchronous) |

**Scaling behavior:**

- Burst: up to 3,000 immediately (in us-east-1), then 500/minute additional.
- Beyond burst, Lambda scales at a rate of 500 instances per minute.

**Best practice:** Set reserved concurrency on critical functions to protect them from noisy-neighbor effects. Use provisioned concurrency for latency-sensitive APIs.

---

### Q2.6: How do you implement the Saga pattern for distributed transactions using AWS Step Functions?

**Answer:**

The Saga pattern manages distributed transactions where each service performs its local transaction and publishes an event. If one step fails, compensating transactions undo the previous steps.

**Step Functions Orchestration Saga (recommended):**

```json
{
  "Comment": "Order Saga",
  "StartAt": "ReserveInventory",
  "States": {
    "ReserveInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:reserveInventory",
      "Next": "ProcessPayment",
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "CancelOrder" }]
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:processPayment",
      "Next": "ConfirmOrder",
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "ReleaseInventory" }]
    },
    "ConfirmOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:confirmOrder",
      "End": true
    },
    "ReleaseInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:releaseInventory",
      "Next": "CancelOrder"
    },
    "CancelOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:cancelOrder",
      "End": true
    }
  }
}
```

**Why Step Functions for Sagas:**

- Built-in error handling with `Catch` and `Retry`.
- Visual workflow debugging in the console.
- Audit trail of every step execution.
- Express Workflows for high-volume, short-duration sagas (up to 5 minutes, up to 100K/sec).
- Standard Workflows for long-running sagas (up to 1 year).

---

## Topic 3 — Application Development & Integration (20%)

*Java, Spring Boot, REST APIs, ReactJS, Swagger, GraphQL.*

---

### Q3.1: How do you design RESTful APIs following best practices? Explain with Spring Boot

**Answer:**

**REST API design principles:**

1. **Resource-based URLs:** `/api/v1/orders/{orderId}` (nouns, not verbs)
2. **HTTP methods map to operations:** GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE
3. **Proper status codes:** 200, 201, 204, 400, 401, 403, 404, 409, 500
4. **Versioning:** URI path (`/v1/`) or header-based (`Accept: application/vnd.api.v1+json`)
5. **HATEOAS:** Include links to related resources in responses
6. **Pagination:** Offset-based or cursor-based for list endpoints

**Spring Boot example:**

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @GetMapping
    public ResponseEntity<Page<OrderDTO>> getOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(orderService.findAll(PageRequest.of(page, size)));
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<OrderDTO> getOrder(@PathVariable UUID orderId) {
        return orderService.findById(orderId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<OrderDTO> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderDTO created = orderService.create(request);
        URI location = URI.create("/api/v1/orders/" + created.getId());
        return ResponseEntity.created(location).body(created);
    }

    @PutMapping("/{orderId}")
    public ResponseEntity<OrderDTO> updateOrder(
            @PathVariable UUID orderId,
            @Valid @RequestBody UpdateOrderRequest request) {
        return ResponseEntity.ok(orderService.update(orderId, request));
    }

    @DeleteMapping("/{orderId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable UUID orderId) {
        orderService.delete(orderId);
    }
}
```

**Global exception handling:**

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(404)
            .body(new ErrorResponse("NOT_FOUND", ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<String> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + ": " + e.getDefaultMessage())
            .toList();
        return ResponseEntity.badRequest()
            .body(new ErrorResponse("VALIDATION_ERROR", errors.toString()));
    }
}
```

---

### Q3.2: What is the difference between REST and GraphQL? When would you use GraphQL?

**Answer:**

| Aspect                        | REST                               | GraphQL                                      |
| ----------------------------- | ---------------------------------- | -------------------------------------------- |
| **Data fetching**       | Fixed structure per endpoint       | Client specifies exact fields needed         |
| **Over/Under-fetching** | Common problem                     | Eliminated — client controls response shape |
| **Endpoints**           | Multiple (one per resource)        | Single endpoint (`/graphql`)               |
| **Versioning**          | URL or header versioning           | Schema evolution (deprecate fields)          |
| **Caching**             | HTTP caching works naturally (GET) | Requires client-side caching (Apollo, Relay) |
| **File uploads**        | Native (multipart)                 | Requires workaround (multipart spec)         |
| **Real-time**           | WebSockets or SSE (custom)         | Built-in subscriptions                       |
| **Tooling**             | Swagger/OpenAPI                    | GraphQL Playground, introspection            |

**Use GraphQL when:**

- Mobile clients need different data shapes than web clients.
- Frontend teams want to iterate rapidly without backend changes.
- You have deeply nested, relational data (e.g., social graph, product catalogs).
- You want to aggregate data from multiple microservices into a single API (GraphQL Federation / Apollo Gateway).

**Use REST when:**

- Simple CRUD APIs with well-defined resources.
- You need HTTP caching extensively.
- File upload/download is a core feature.
- Your team is more experienced with REST.

**Spring Boot GraphQL example:**

```java
@Controller
public class OrderGraphQLController {

    @QueryMapping
    public List<Order> orders(@Argument String status) {
        return orderService.findByStatus(status);
    }

    @MutationMapping
    public Order createOrder(@Argument CreateOrderInput input) {
        return orderService.create(input);
    }

    @SchemaMapping(typeName = "Order", field = "customer")
    public Customer customer(Order order) {
        return customerService.findById(order.getCustomerId());
    }
}
```

---

### Q3.3: How do you document APIs using Swagger/OpenAPI in Spring Boot?

**Answer:**

**Using `springdoc-openapi` (recommended for Spring Boot 3.x):**

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

**Annotating controllers:**

```java
@RestController
@RequestMapping("/api/v1/orders")
@Tag(name = "Orders", description = "Order management APIs")
public class OrderController {

    @Operation(
        summary = "Create a new order",
        description = "Creates an order and returns the created resource",
        responses = {
            @ApiResponse(responseCode = "201", description = "Order created"),
            @ApiResponse(responseCode = "400", description = "Invalid request body"),
            @ApiResponse(responseCode = "409", description = "Duplicate order")
        }
    )
    @PostMapping
    public ResponseEntity<OrderDTO> createOrder(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "Order creation payload",
                required = true
            )
            @Valid @RequestBody CreateOrderRequest request) {
        // ...
    }
}
```

**Access:**

- Swagger UI: `http://localhost:8080/swagger-ui.html`
- OpenAPI JSON: `http://localhost:8080/v3/api-docs`
- OpenAPI YAML: `http://localhost:8080/v3/api-docs.yaml`

**Best practices:**

- Use `@Schema` annotations on DTOs for field documentation.
- Enable API grouping for microservices.
- Generate client SDKs from the OpenAPI spec using `openapi-generator`.
- Integrate spec validation into CI/CD pipeline.

---

### Q3.4: How would you structure a React application for a large-scale enterprise project?

**Answer:**

**Recommended folder structure (feature-based):**

```
src/
├── app/                    # App-level setup
│   ├── App.tsx
│   ├── routes.tsx          # React Router config
│   └── store.ts            # Redux/Zustand store
├── features/               # Feature modules
│   ├── orders/
│   │   ├── api/            # API calls (React Query hooks)
│   │   ├── components/     # Feature-specific components
│   │   ├── hooks/          # Custom hooks
│   │   ├── pages/          # Page components
│   │   ├── types/          # TypeScript interfaces
│   │   └── index.ts        # Public API (barrel export)
│   ├── auth/
│   └── dashboard/
├── shared/                 # Shared across features
│   ├── components/         # Reusable UI components
│   ├── hooks/
│   ├── utils/
│   └── constants/
├── services/               # API client, auth service
└── styles/                 # Global styles, theme
```

**Key architecture decisions:**

- **State management:** React Query for server state (caching, sync), Zustand/Redux Toolkit for client state.
- **API layer:** Centralized Axios instance with interceptors for auth tokens, error handling.
- **Routing:** React Router v6 with lazy loading (`React.lazy` + `Suspense`).
- **Type safety:** TypeScript throughout; generate API types from OpenAPI/Swagger spec.
- **Testing:** React Testing Library + Vitest; MSW for API mocking.
- **Performance:** Code splitting per route, memoization (`useMemo`, `React.memo`), virtualization for long lists (`react-window`).

---

### Q3.5: Explain the Circuit Breaker pattern. How do you implement it in a Spring Boot microservice?

**Answer:**

**Problem:** When a downstream service is failing, continuing to call it wastes resources and cascades failures.

**Circuit Breaker states:**

- **CLOSED:** Requests flow normally. Failures are counted.
- **OPEN:** After failure threshold is breached, all requests fail immediately without calling the downstream. A timer starts.
- **HALF-OPEN:** After the timer expires, a limited number of test requests are allowed through. If they succeed, circuit closes. If they fail, circuit re-opens.

**Implementation with Resilience4j (Spring Boot):**

```java
// application.yml
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 10s
        permittedNumberOfCallsInHalfOpenState: 3
        slowCallDurationThreshold: 2s
        slowCallRateThreshold: 80

// Service class
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentClient paymentClient;

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    @Retry(name = "paymentService")
    @TimeLimiter(name = "paymentService")
    public CompletableFuture<PaymentResponse> processPayment(PaymentRequest request) {
        return CompletableFuture.supplyAsync(() -> paymentClient.charge(request));
    }

    private CompletableFuture<PaymentResponse> paymentFallback(
            PaymentRequest request, Throwable t) {
        // Queue for retry, return pending status
        return CompletableFuture.completedFuture(
            PaymentResponse.pending("Payment queued for retry"));
    }
}
```

---

### Q3.6: How do you secure REST APIs in Spring Boot?

**Answer:**

**Multi-layered security:**

1. **Authentication (Spring Security + JWT):**

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm -> sm.sessionCreationPolicy(STATELESS))
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            );
        return http.build();
    }
}
```

1. **Authorization:** Role-based (`@PreAuthorize("hasRole('ADMIN')")`) or attribute-based access control.
2. **Input validation:** `@Valid` with Bean Validation (JSR-380).
3. **Rate limiting:** Spring Cloud Gateway or Resilience4j `@RateLimiter`.
4. **CORS:** Configure allowed origins explicitly.
5. **API Gateway (AWS):** Cognito authorizer or Lambda authorizer at the edge.

---

## Topic 4 — Data Stores & Search Platforms (15%)

*OpenSearch and MongoDB.*

---

### Q4.1: When would you choose MongoDB over a relational database? Explain with use cases

**Answer:**

**Choose MongoDB when:**

| Criteria                           | MongoDB Advantage                                                                              |
| ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Schema flexibility**       | Schema-less documents allow rapid iteration; different documents can have different structures |
| **Hierarchical/nested data** | Embedded documents avoid expensive JOINs (e.g., a product with variants, reviews, images)      |
| **High write throughput**    | Horizontal scaling via sharding across commodity hardware                                      |
| **Geospatial queries**       | Native`2dsphere` indexes for location-based queries                                          |
| **Rapid prototyping**        | No schema migrations needed; add fields freely                                                 |

**Use cases ideal for MongoDB:**

- **E-commerce product catalogs** — variable attributes per product category
- **Content management** — articles, blog posts with embedded media metadata
- **IoT/telemetry** — high-volume time-series data with TTL indexes
- **User profiles** — flexible schema with embedded preferences
- **Real-time analytics** — aggregation pipeline for complex analytics

**Choose RDBMS (PostgreSQL/MySQL/Aurora) when:**

- Strong ACID transactions across multiple entities.
- Complex relational queries with many JOINs.
- Regulatory requirements for strict data consistency.
- Well-defined, stable schema.

---

### Q4.2: Explain MongoDB indexing strategies for performance optimization

**Answer:**

**Index types:**

| Index Type                      | Use Case                                     | Example                                                                                    |
| ------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **Single field**          | Equality/range queries on one field          | `db.orders.createIndex({ status: 1 })`                                                   |
| **Compound**              | Queries filtering/sorting on multiple fields | `db.orders.createIndex({ customerId: 1, createdAt: -1 })`                                |
| **Multikey**              | Indexing array fields                        | `db.products.createIndex({ tags: 1 })`                                                   |
| **Text**                  | Full-text search                             | `db.articles.createIndex({ content: "text" })`                                           |
| **Geospatial (2dsphere)** | Location queries                             | `db.stores.createIndex({ location: "2dsphere" })`                                        |
| **Hashed**                | Hash-based sharding                          | `db.users.createIndex({ userId: "hashed" })`                                             |
| **TTL**                   | Auto-delete expired documents                | `db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 })`                   |
| **Partial**               | Index only documents matching a filter       | `db.orders.createIndex({ total: 1 }, { partialFilterExpression: { status: "active" } })` |

**ESR Rule (Equality → Sort → Range):**
For compound indexes, order fields as:

1. **Equality** conditions first (`status: "active"`)
2. **Sort** fields next (`createdAt: -1`)
3. **Range** conditions last (`total: { $gt: 100 }`)

```javascript
// Query: find active orders > $100, sorted by date
db.orders.find({ status: "active", total: { $gt: 100 } }).sort({ createdAt: -1 })

// Optimal index (ESR rule):
db.orders.createIndex({ status: 1, createdAt: -1, total: 1 })
```

**Performance analysis:**

```javascript
db.orders.find({ status: "active" }).explain("executionStats")
// Look for: totalDocsExamined vs. nReturned — ratio should be close to 1:1
```

---

### Q4.3: What is Amazon OpenSearch? How does it differ from Elasticsearch?

**Answer:**

**Amazon OpenSearch Service** is a fully managed service for OpenSearch (the open-source fork of Elasticsearch 7.10.2). It provides search, log analytics, and observability at scale.

| Aspect                 | Amazon OpenSearch                                           | Self-managed Elasticsearch                       |
| ---------------------- | ----------------------------------------------------------- | ------------------------------------------------ |
| **Management**   | Fully managed (patching, backups, scaling)                  | Self-managed                                     |
| **Licensing**    | Apache 2.0 (open source)                                    | Elastic License 2.0 (not open source since 7.11) |
| **Cost**         | Per-instance-hour + storage                                 | Infrastructure cost + operational overhead       |
| **Integrations** | Native Kinesis Firehose, CloudWatch, IAM                    | Manual setup                                     |
| **Security**     | Fine-grained access control, VPC, encryption                | X-Pack (paid in Elastic)                         |
| **Plugins**      | Pre-installed anomaly detection, alerting, SQL              | Varies                                           |
| **Serverless**   | OpenSearch Serverless (auto-scaling, no cluster management) | Not available                                    |

---

### Q4.4: Design a search architecture using OpenSearch for an e-commerce platform

**Answer:**

```
┌──────────┐     ┌──────────────┐     ┌───────────────┐
│ MongoDB  │────▶│ Change Stream│────▶│ Lambda / MSK  │
│ (Source  │     │ (CDC)        │     │ Connect       │
│  of truth)│    └──────────────┘     └───────┬───────┘
└──────────┘                                  │ Transform & index
                                       ┌──────▼──────┐
                                       │  OpenSearch  │
                                       │  Cluster     │
                                       └──────┬──────┘
                                              │
                                    ┌─────────▼─────────┐
                                    │   API Gateway +   │
                                    │   Lambda (Search  │
                                    │   API)            │
                                    └─────────┬─────────┘
                                              │
                                       ┌──────▼──────┐
                                       │  React App  │
                                       └─────────────┘
```

**Index design for products:**

```json
{
  "mappings": {
    "properties": {
      "name": { "type": "text", "analyzer": "standard", "fields": { "keyword": { "type": "keyword" } } },
      "description": { "type": "text", "analyzer": "english" },
      "category": { "type": "keyword" },
      "brand": { "type": "keyword" },
      "price": { "type": "float" },
      "ratings": { "type": "float" },
      "attributes": { "type": "nested" },
      "suggest": { "type": "completion" },
      "location": { "type": "geo_point" }
    }
  },
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "autocomplete": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "edge_ngram_filter"]
        }
      },
      "filter": {
        "edge_ngram_filter": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 15
        }
      }
    }
  }
}
```

**Search API features:**

- **Full-text search** with relevance scoring (`multi_match` across name, description, category)
- **Faceted search** using `aggregations` (brand, category, price range, rating)
- **Autocomplete** using `completion` suggester
- **Fuzzy matching** for typo tolerance
- **Synonyms** via synonym token filter
- **Geo-distance** filtering for nearby stores
- **Personalized ranking** using function_score with user preferences

---

### Q4.5: How do you implement data synchronization between MongoDB and OpenSearch?

**Answer:**

**Approach 1: Change Data Capture (CDC) — Recommended**

```
MongoDB → Change Stream → Lambda → OpenSearch
```

```javascript
// Lambda handler for MongoDB Change Stream events (via EventBridge Pipe or Trigger)
exports.handler = async (event) => {
    const { operationType, fullDocument, documentKey } = event.detail;
    const client = new OpenSearchClient(/* config */);

    switch (operationType) {
        case 'insert':
        case 'update':
        case 'replace':
            await client.index({
                index: 'products',
                id: documentKey._id.toString(),
                body: transformToSearchDoc(fullDocument)
            });
            break;
        case 'delete':
            await client.delete({
                index: 'products',
                id: documentKey._id.toString()
            });
            break;
    }
};
```

**Approach 2: Bulk sync for initial load**

```javascript
// Use MongoDB Aggregation + OpenSearch Bulk API
const cursor = db.products.find({}).batchSize(1000);
let bulk = [];

while (await cursor.hasNext()) {
    const doc = await cursor.next();
    bulk.push({ index: { _index: 'products', _id: doc._id.toString() } });
    bulk.push(transformToSearchDoc(doc));

    if (bulk.length >= 2000) {  // 1000 docs × 2 lines each
        await opensearchClient.bulk({ body: bulk });
        bulk = [];
    }
}
```

**Best practices:**

- Use **DLQ** for failed indexing operations.
- Implement **idempotent writes** (use MongoDB `_id` as OpenSearch `_id`).
- Monitor **replication lag** between MongoDB and OpenSearch.
- Run periodic **consistency checks** comparing document counts and checksums.

---

## Topic 5 — DevOps, IaC & Container Management (15%)

*Terraform, Docker, Kubernetes.*

---

### Q5.1: Explain Terraform state management. What are the best practices?

**Answer:**

**Terraform state** is a JSON file (`terraform.tfstate`) that maps real-world resources to your configuration. It's the source of truth for what Terraform manages.

**Best practices:**

1. **Remote state with S3 + DynamoDB:**

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/vpc/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"   # State locking
  }
}
```

1. **State locking:** DynamoDB table prevents concurrent modifications.
2. **State file organization (per-environment, per-component):**

```
terraform/
├── modules/           # Reusable modules
│   ├── vpc/
│   ├── ecs-cluster/
│   └── rds/
├── environments/
│   ├── dev/
│   │   ├── vpc/       # Each has its own state file
│   │   ├── app/
│   │   └── database/
│   ├── staging/
│   └── prod/
```

1. **Never edit state manually.** Use `terraform state mv`, `terraform state rm`, `terraform import`.
2. **Enable versioning** on the S3 bucket for state rollback.
3. **Use `terraform plan` output in CI/CD** — review plan before apply.
4. **Sensitive data:** Use `sensitive = true` on variables; state encryption at rest.

---

### Q5.2: Write Terraform code to deploy a highly available ECS Fargate service with ALB

**Answer:**

```hcl
# --- VPC & Networking ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "app-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # One NAT per AZ for HA
  enable_dns_hostnames = true
}

# --- ALB ---
resource "aws_lb" "app" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "app" {
  name        = "app-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"  # Required for Fargate

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- ECS Cluster & Service ---
resource "aws_ecs_cluster" "main" {
  name = "app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "app"
    image = "${var.ecr_repo_url}:${var.image_tag}"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/app"
        "awslogs-region"        = "ap-south-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.environment }
    ]
    secrets = [
      { name = "DB_PASSWORD", valueFrom = var.db_password_secret_arn }
    ]
  }])
}

resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

# --- Auto Scaling ---
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "cpu-scaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

---

### Q5.3: Explain multi-stage Docker builds. Why are they important?

**Answer:**

Multi-stage builds use multiple `FROM` statements in a single Dockerfile. Each stage can use a different base image. The final image only contains what's copied from previous stages, resulting in smaller, more secure images.

```dockerfile
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline          # Cache dependencies
COPY src ./src
RUN mvn package -DskipTests -q

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

**Benefits:**

| Aspect                | Single-stage                          | Multi-stage                                  |
| --------------------- | ------------------------------------- | -------------------------------------------- |
| **Image size**  | ~800MB (includes JDK, Maven, source)  | ~180MB (JRE + JAR only)                      |
| **Security**    | Build tools, source code exposed      | Minimal attack surface                       |
| **Build cache** | Dependencies re-downloaded every time | `dependency:go-offline` cached in layer    |
| **Secrets**     | Build-time secrets may leak           | Secrets stay in build stage, not final image |

---

### Q5.4: How do you design a Kubernetes deployment for a microservices application on EKS?

**Answer:**

**Kubernetes manifests:**

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: production
  labels:
    app: order-service
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0        # Zero-downtime deployment
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        version: v1
    spec:
      serviceAccountName: order-service-sa
      containers:
        - name: order-service
          image: 123456789.dkr.ecr.ap-south-1.amazonaws.com/order-service:v1.2.3
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "500m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 15
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "production"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: order-db-credentials
                  key: password
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: order-service
---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order-service
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
---
# pdb.yaml (Pod Disruption Budget)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-service-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: order-service
```

**EKS-specific best practices:**

- **IAM Roles for Service Accounts (IRSA):** Map K8s ServiceAccounts to IAM roles — no instance-profile sharing.
- **Karpenter** for node auto-scaling (faster than Cluster Autoscaler).
- **AWS Load Balancer Controller** for ALB/NLB Ingress.
- **External Secrets Operator** to sync AWS Secrets Manager → K8s Secrets.
- **Topology spread constraints** to distribute pods across AZs.

---

### Q5.5: Explain a CI/CD pipeline for deploying a Spring Boot application to EKS

**Answer:**

```
┌──────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────┐
│ Git  │───▶│  Build & │───▶│  Docker  │───▶│ Deploy   │───▶│ EKS  │
│ Push │    │  Test    │    │  Build & │    │ (Helm/   │    │      │
│      │    │ (Maven)  │    │  Push ECR│    │  ArgoCD) │    │      │
└──────┘    └──────────┘    └──────────┘    └──────────┘    └──────┘
                │                                 │
           ┌────▼────┐                      ┌─────▼────┐
           │ SonarQube│                     │ Canary / │
           │ Trivy    │                     │ Blue-Green│
           └─────────┘                      └──────────┘
```

**Pipeline stages (GitHub Actions / CodePipeline):**

1. **Source:** Git push triggers pipeline.
2. **Build & Test:** `mvn clean verify` — unit tests, integration tests.
3. **Static Analysis:** SonarQube scan, dependency vulnerability check.
4. **Docker Build:** Multi-stage build → push to ECR.
5. **Image Scan:** Trivy / ECR scanning for vulnerabilities.
6. **Deploy to Staging:** Helm upgrade or ArgoCD sync to staging namespace.
7. **Integration/Smoke Tests:** Run against staging.
8. **Deploy to Production:** Canary deployment (10% → 50% → 100%) using Argo Rollouts or Flagger.
9. **Post-deployment verification:** Health checks, synthetic monitoring.

---

### Q5.6: What are Terraform modules? How do you structure them for reusability?

**Answer:**

**A Terraform module** is a container for multiple resources that are used together. Every Terraform configuration is a module (the root module). Child modules are called from the root to encapsulate and reuse infrastructure patterns.

**Module structure:**

```
modules/
└── ecs-service/
    ├── main.tf          # Resource definitions
    ├── variables.tf     # Input variables
    ├── outputs.tf       # Output values
    ├── versions.tf      # Provider version constraints
    └── README.md        # Documentation
```

**Example module (`modules/ecs-service/main.tf`):**

```hcl
variable "service_name" {
  type        = string
  description = "Name of the ECS service"
}

variable "container_image" {
  type        = string
  description = "Docker image URI"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "environment" {
  type    = string
  default = "dev"
}

# Resources: task definition, service, security group, etc.
resource "aws_ecs_task_definition" "this" {
  family = "${var.service_name}-${var.environment}"
  # ... (uses variables)
}

output "service_arn" {
  value = aws_ecs_service.this.id
}
```

**Usage:**

```hcl
module "order_service" {
  source          = "../../modules/ecs-service"
  service_name    = "order-service"
  container_image = "123456789.dkr.ecr.ap-south-1.amazonaws.com/order:v1.2"
  desired_count   = 3
  environment     = "prod"
}

module "payment_service" {
  source          = "../../modules/ecs-service"
  service_name    = "payment-service"
  container_image = "123456789.dkr.ecr.ap-south-1.amazonaws.com/payment:v2.0"
  desired_count   = 2
  environment     = "prod"
}
```

**Best practices:**

- **Pin module versions** when using remote modules (Terraform Registry or Git tags).
- **Validate inputs** using `validation` blocks on variables.
- **Use `locals`** for computed values.
- **Output everything** downstream modules might need.
- **Document** every variable and output.

---

## Topic 6 — Monitoring, Logging & Observability (10%)

*Splunk and Splunk Query Language (SPL).*

---

### Q6.1: What are the three pillars of observability? How do they relate to each other?

**Answer:**

| Pillar            | What It Is                                                                 | AWS/Splunk Tool                    |
| ----------------- | -------------------------------------------------------------------------- | ---------------------------------- |
| **Logs**    | Discrete events with timestamps and context (structured/unstructured text) | Splunk, CloudWatch Logs            |
| **Metrics** | Numeric measurements over time (counters, gauges, histograms)              | CloudWatch Metrics, Splunk Metrics |
| **Traces**  | End-to-end request path across distributed services with timing            | X-Ray, Splunk APM                  |

**How they work together:**

- A **metric alert** fires (e.g., p99 latency > 2s).
- You pivot to **traces** to find which service is slow.
- You drill into **logs** for that service to see the error details.

**Additional dimension — Events:**

- Deployments, config changes, incidents.
- Correlating events with metrics/logs helps identify root causes (e.g., latency spike after a deployment).

---

### Q6.2: Write Splunk SPL queries for common operational scenarios

**Answer:**

**1. Find errors in the last 1 hour with count by service:**

```spl
index=production sourcetype=app_logs level=ERROR earliest=-1h
| stats count by service, error_code
| sort -count
```

**2. Calculate p50, p95, p99 response times per API endpoint:**

```spl
index=production sourcetype=access_logs
| stats perc50(response_time) as p50,
        perc95(response_time) as p95,
        perc99(response_time) as p99
  by endpoint
| sort -p99
```

**3. Detect anomalous error rate spikes:**

```spl
index=production sourcetype=app_logs
| timechart span=5m count(eval(level="ERROR")) as error_count,
             count as total_count
| eval error_rate = round((error_count / total_count) * 100, 2)
| anomalydetection error_rate
```

**4. Track deployment impact — compare before/after:**

```spl
index=production sourcetype=access_logs
| eval period = if(_time < relative_time(now(), "-1h"), "before", "after")
| stats avg(response_time) as avg_latency,
        perc99(response_time) as p99_latency,
        count(eval(status >= 500)) as errors
  by period
```

**5. Find the slowest database queries:**

```spl
index=production sourcetype=app_logs "db.query"
| rex field=_raw "query_time=(?<query_time>\d+\.?\d*)"
| where query_time > 1.0
| stats count, avg(query_time) as avg_time, max(query_time) as max_time
  by query_text
| sort -avg_time
| head 20
```

**6. User session analysis — trace a request across services:**

```spl
index=production trace_id="abc123def456"
| sort _time
| table _time, service, span_id, parent_span_id, operation, duration_ms, status
```

**7. Create a dashboard panel — real-time error rate with threshold:**

```spl
index=production sourcetype=app_logs
| timechart span=1m count(eval(level="ERROR")) as errors,
                     count as total
| eval error_pct = round((errors/total)*100, 2)
| eval threshold = 5
| eval alert = if(error_pct > threshold, "CRITICAL", "OK")
```

---

### Q6.3: How do you implement a centralized logging strategy for microservices on AWS with Splunk?

**Answer:**

**Architecture:**

```
┌────────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────┐
│ ECS/EKS    │────▶│ CloudWatch   │────▶│ Kinesis Data  │────▶│  Splunk  │
│ Containers │     │ Logs         │     │ Firehose      │     │  Cloud / │
│ (stdout)   │     │              │     │               │     │  HEC     │
└────────────┘     └──────────────┘     └───────────────┘     └──────────┘
                                                                    │
┌────────────┐     ┌──────────────┐                            ┌────▼─────┐
│ Lambda     │────▶│ CloudWatch   │───── (same pipeline) ────▶│ Indexes  │
│ Functions  │     │ Logs         │                            │ Dashboards│
└────────────┘     └──────────────┘                            │ Alerts   │
                                                               └──────────┘
```

**Implementation steps:**

1. **Structured logging** — Use JSON format from all services:

```java
// logback-spring.xml (Spring Boot)
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"service":"order-service","environment":"prod"}</customFields>
</encoder>
```

Output:

```json
{
  "timestamp": "2025-06-26T10:15:30Z",
  "level": "ERROR",
  "service": "order-service",
  "trace_id": "abc123",
  "span_id": "def456",
  "message": "Payment processing failed",
  "error_code": "PAY_001",
  "customer_id": "C12345"
}
```

1. **Ship logs:** CloudWatch Logs → Subscription Filter → Kinesis Firehose → Splunk HEC (HTTP Event Collector).
2. **Index strategy in Splunk:**

   - `index=production` — production logs
   - `index=staging` — staging logs
   - `index=infrastructure` — AWS service logs (VPC Flow, CloudTrail)
   - Retention: 30 days hot, 90 days warm, 1 year cold (frozen to S3).
3. **Correlation:** Include `trace_id` in all logs for cross-service correlation.
4. **Alerting:** Set up Splunk alerts for SLA breaches, error rate spikes, and security events.

---

### Q6.4: How do you set up alerting and SLA monitoring in Splunk?

**Answer:**

**1. Define SLIs and SLOs:**

| Service         | SLI (Indicator)          | SLO (Objective)    | Alert Threshold                      |
| --------------- | ------------------------ | ------------------ | ------------------------------------ |
| Order API       | Availability (2xx/total) | 99.9% over 30 days | < 99.5% in 5 min window              |
| Order API       | p99 latency              | < 500ms            | > 1000ms for 3 consecutive intervals |
| Payment Service | Error rate               | < 0.1%             | > 1% in 5 min window                 |

**2. Splunk saved search / alert:**

```spl
index=production sourcetype=access_logs service="order-api" earliest=-5m
| stats count(eval(status<500)) as success,
        count as total
| eval availability = round((success/total)*100, 3)
| where availability < 99.5
```

**Alert configuration:**

- **Trigger:** When results > 0
- **Throttle:** 15 minutes (avoid alert storms)
- **Actions:** PagerDuty integration, Slack webhook, email
- **Severity:** Based on SLO burn rate

**3. Error budget tracking:**

```spl
index=production sourcetype=access_logs service="order-api" earliest=-30d
| timechart span=1d count(eval(status<500)) as success, count as total
| eval daily_availability = (success/total)*100
| eval error_budget_total = (1 - 99.9/100) * 100
| eval error_budget_consumed = (1 - daily_availability/100) * 100
| streamstats sum(error_budget_consumed) as cumulative_budget_used
| eval budget_remaining = error_budget_total - cumulative_budget_used
```

---

## Bonus — Scenario-Based / System Design Questions

---

### SQ1: Design a real-time notification system for a banking application on AWS

**Answer:**

**Requirements:** Push notifications, SMS, email, in-app notifications. Must handle 1M+ users, < 5 second delivery.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Transaction  │────▶│  EventBridge │────▶│ Lambda       │
│ Service      │     │  (event bus) │     │ (Router)     │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │ Route by preference
                                    ┌─────────────┼─────────────┐
                                    │             │             │
                             ┌──────▼─────┐ ┌────▼──────┐ ┌───▼──────┐
                             │ SNS (Push) │ │ SES       │ │ Pinpoint │
                             │ + FCM/APNs │ │ (Email)   │ │ (SMS)    │
                             └────────────┘ └───────────┘ └──────────┘
                                                  │
                                           ┌──────▼──────┐
                                           │ DynamoDB    │
                                           │ (In-App     │
                                           │  Notif. Log)│
                                           └─────────────┘
                                                  │
                                           ┌──────▼──────┐
                                           │ API Gateway │
                                           │ + WebSocket │
                                           │ (Real-time) │
                                           └─────────────┘
```

**Key decisions:**

- **EventBridge** for event routing — content-based rules (transaction amount > 10K → SMS + email).
- **API Gateway WebSocket** for real-time in-app delivery.
- **DynamoDB** with TTL for notification history (90-day retention).
- **SQS DLQ** per channel for failed deliveries.
- **User preferences** stored in DynamoDB — channels, quiet hours, frequency caps.
- **Encryption:** All PII encrypted with KMS CMK.

---

### SQ2: How would you migrate a legacy on-premise Oracle-based application to AWS?

**Answer:**

**Phase 1: Assessment (2-4 weeks)**

- Inventory existing components, dependencies, data volumes.
- Use **AWS Migration Hub** + **Application Discovery Service**.
- Assess database: schema complexity, stored procedures, data size.
- Decide: rehost, re-platform, or refactor.

**Phase 2: Database Migration (4-8 weeks)**

- **Tool:** AWS Database Migration Service (DMS) + Schema Conversion Tool (SCT).
- **Target options:**
  - Aurora PostgreSQL (recommended — 80% cost reduction vs. Oracle, compatible with most SQL).
  - RDS Oracle (if refactoring is not feasible).
- **Strategy:** Continuous replication (CDC) with DMS until cutover.

**Phase 3: Application Migration (6-12 weeks)**

- **Lift & shift** to EC2 initially (minimize risk).
- Containerize with Docker → deploy to ECS/EKS.
- Refactor stored procedures → Java/Spring Boot services.
- Replace Oracle-specific SQL (PL/SQL) → standard SQL + application logic.

**Phase 4: Modernization (ongoing)**

- Break monolith → microservices (Strangler Fig pattern).
- Move to serverless where appropriate.
- Implement CI/CD, IaC, monitoring.

---

## Soft Skills & Behavioral Questions

---

### B1: Describe a time you had to make a critical architecture decision under pressure. What was the outcome?

**Model answer structure (STAR):**

- **Situation:** Production system experiencing cascading failures during peak traffic (Black Friday).
- **Task:** Needed to quickly decide between adding more instances ($$) or implementing circuit breakers + caching.
- **Action:** Implemented Redis caching for product catalog (80% of read traffic) + circuit breaker on payment service. Deployed via feature flag in 2 hours.
- **Result:** Reduced DB load by 75%, stabilized latency under 200ms. The temporary fix became the permanent architecture improvement.

---

### B2: How do you handle disagreements with development teams about technology choices?

**Model answer points:**

- Start with **data, not opinions** — POC, benchmarks, total cost of ownership.
- Create an **Architecture Decision Record (ADR)** documenting options, trade-offs, and rationale.
- Seek **alignment on requirements first** (non-functional: scalability, team skills, timeline).
- Be willing to **compromise** if the alternative meets requirements, even if it's not your first choice.
- Escalate to **architecture review board** only if consensus cannot be reached.

---

### B3: How do you ensure knowledge sharing across distributed teams?

**Model answer points:**

- **Architecture Decision Records (ADRs)** — documented in Git alongside code.
- **Tech talks / brown-bag sessions** — weekly, rotating presenters.
- **Runbooks and playbooks** — Confluence/Wiki for operational procedures.
- **Code reviews** — ensure cross-team reviewers.
- **Architecture diagrams** — kept up-to-date in draw.io/Lucidchart, linked from README.
- **Pairing sessions** — especially during onboarding or complex features.

---

> [!TIP]
> **Preparation tips:**
>
> - Be ready to **whiteboard** any architecture on demand.
> - Have **2-3 real project examples** for each topic area.
> - Know **AWS pricing models** — interviewers often ask about cost optimization.
> - Be comfortable with **hands-on coding** — expect live coding in Java/Spring Boot.
> - Review the **AWS Well-Architected Framework** whitepaper.
> - Practice SPL queries — interviewers may ask you to write them live.
