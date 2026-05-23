# Production Architecture — DevSecOps Pipeline

## Table of Contents

1. [System Overview](#1-system-overview)
2. [End-to-End Pipeline](#2-end-to-end-pipeline)
3. [AWS Infrastructure](#3-aws-infrastructure-layout)
4. [Network Topology](#4-network-topology)
5. [CI Pipeline Detail](#5-ci-pipeline---12-stage-detail)
6. [CD Pipeline &amp; GitOps](#6-cd-pipeline--gitops-flow)
7. [Security Architecture](#7-security-architecture---defense-in-depth)
8. [Cognito Authentication](#8-cognito-authentication-flow)
9. [Request Traffic Flow](#9-request-traffic-flow---edge-to-pod)
10. [VPC Endpoint Connectivity](#10-vpc-endpoint-connectivity)
11. [Terraform Dependency Graph](#11-terraform-resource-dependency-graph)
12. [Component Summary](#12-component-summary)

---

## 1. System Overview

This production-grade DevSecOps pipeline automates the entire software delivery lifecycle:

- **Source**: GitHub repository
- **CI**: GitHub Actions (build, test, SAST, SCA, container scan, ECR push)
- **CD**: GitHub Actions (update manifest) then ArgoCD (deploy to EKS)
- **Runtime**: Private EKS cluster behind ALB + WAF + API Gateway + Cognito
- **Auth**: GitHub OIDC (keyless CI/CD) + Cognito JWT (user auth)
- **Infrastructure**: 100% Terraform-managed

---

## 2. End-to-End Pipeline

```mermaid
graph TB
    subgraph DEVELOPER["Developer Workstation"]
        DEV_CODE["Write Code<br>Java + Spring Boot"]
        DEV_PUSH["git push origin main"]
        DEV_CODE --> DEV_PUSH
    end

    subgraph GITHUB["GitHub"]
        GH_REPO["Application Repository<br>Java_DevSecOps"]
        GH_WEBHOOK["Webhook Trigger<br>on: push to main"]
        GH_MANIFEST["Manifest Repository<br>boardgame-k8s-manifests"]
        GH_REPO --> GH_WEBHOOK
    end

    subgraph CI["GitHub Actions CI Workflow"]
        CI_01["1. Checkout Code"]
        CI_02["2. Setup Java 17 + Maven"]
        CI_03["3. Compile"]
        CI_04["4. Unit Tests + JaCoCo"]
        CI_05["5. SAST: SonarCloud"]
        CI_06["6. Quality Gate Check"]
        CI_07["7. SCA: OWASP DC"]
        CI_08["8. Build JAR"]
        CI_09["9. Docker Build"]
        CI_10["10. Trivy Image Scan"]
        CI_11["11. OIDC Auth + ECR Push"]
        CI_12["12. Trigger CD Workflow"]

        CI_01 --> CI_02 --> CI_03 --> CI_04 --> CI_05
        CI_05 --> CI_06 --> CI_07 --> CI_08 --> CI_09
        CI_09 --> CI_10 --> CI_11 --> CI_12
    end

    subgraph OIDC["GitHub OIDC Federation"]
        GH_JWT["GitHub JWT Token"]
        STS["AWS STS AssumeRole"]
        TEMP_CREDS["Temporary Credentials<br>15-min TTL"]
        GH_JWT --> STS --> TEMP_CREDS
    end

    subgraph REGISTRIES["Container Registry"]
        ECR["Amazon ECR<br>Scan-on-push enabled"]
    end

    subgraph CD["GitHub Actions CD Workflow"]
        CD_01["1. Checkout Manifests"]
        CD_02["2. Update Image Tag"]
        CD_03["3. Commit + Push"]
        CD_01 --> CD_02 --> CD_03
    end

    subgraph GITOPS["ArgoCD GitOps Controller"]
        ARGO_POLL["Poll Git repo<br>Every 3 minutes"]
        ARGO_DIFF["Detect drift"]
        ARGO_SYNC["kubectl apply"]
        ARGO_HEALTH["Health check"]
        ARGO_POLL --> ARGO_DIFF --> ARGO_SYNC --> ARGO_HEALTH
    end

    subgraph EKSCLUSTER["Private EKS Cluster"]
        ROLLING["Rolling Update"]
        PULL_IMAGE["Pull from ECR<br>via VPC Endpoint"]
        HEALTH_CHECK["Readiness Probe<br>/actuator/health"]
        LIVE["Application LIVE<br>Multi-AZ"]
        ROLLING --> PULL_IMAGE --> HEALTH_CHECK --> LIVE
    end

    DEV_PUSH --> GH_REPO
    GH_WEBHOOK --> CI_01
    CI_11 --> GH_JWT
    TEMP_CREDS --> ECR
    CI_12 --> CD_01
    CD_03 --> GH_MANIFEST
    GH_MANIFEST --> ARGO_POLL
    ARGO_SYNC --> ROLLING
    ECR -.-> PULL_IMAGE
```

![1776175327776](image/architecture/1776175327776.png)

---

## 3. AWS Infrastructure Layout

![1776175640160](image/architecture/1776175640160.png)

![1776175709919](image/architecture/1776175709919.png)

---

## 4. Network Topology

```mermaid
graph LR
    subgraph INBOUND["Inbound Traffic"]
        I1["HTTPS:443"]
        I2["HTTP:80 redirect 301"]
    end

    subgraph PUB_LAYER["Public Subnets"]
        IGW_N["Internet Gateway"]
        ALB_N["ALB<br>SG: 80,443 from 0.0.0.0/0"]
        BASTION_N["Bastion<br>SG: 22 from admin IP"]
        NAT_N["NAT Gateway"]
    end

    subgraph PRIV_LAYER["Private Subnets"]
        EKS_API["EKS API :443<br>from VPC CIDR"]
        EKS_NODES_N["EKS Nodes<br>SG: 8080 from ALB<br>10250 from control plane"]
    end

    subgraph VPCE_LAYER["VPC Endpoints"]
        VPCE_IF["Interface Endpoints<br>ECR, STS, CW, EKS"]
        VPCE_GW["Gateway Endpoint<br>S3 - free"]
    end

    subgraph OUTBOUND["Outbound Traffic"]
        O1["ECR image pull"]
        O2["STS token exchange"]
        O3["CloudWatch logs"]
        O4["Internet via NAT"]
    end

    I1 --> IGW_N --> ALB_N --> EKS_NODES_N
    I2 --> IGW_N
    BASTION_N --> EKS_API
    EKS_NODES_N --> VPCE_IF
    EKS_NODES_N --> VPCE_GW
    EKS_NODES_N --> NAT_N --> IGW_N
    VPCE_IF --> O1
    VPCE_IF --> O2
    VPCE_IF --> O3
    NAT_N --> O4
```

---

## 5. CI Pipeline — 12-Stage Detail

```mermaid
graph TB
    subgraph TRIGGER["Trigger"]
        T1["git push to main<br>or PR opened"]
    end

    subgraph BUILD_PHASE["Build Phase"]
        S1["1. CHECKOUT<br>actions/checkout@v4"]
        S2["2. SETUP JAVA<br>Temurin JDK 17"]
        S3["3. COMPILE<br>mvn compile"]
    end

    subgraph TEST_PHASE["Test Phase"]
        S4["4. UNIT TESTS<br>JUnit 5 + JaCoCo"]
        S4_OUT["Artifact: test reports"]
    end

    subgraph SECURITY_PHASE["Security Scanning"]
        S5["5. SAST<br>SonarCloud"]
        S5_IN["JaCoCo XML + binaries"]
        S6["6. QUALITY GATE<br>Pass or Fail"]
        S7["7. SCA<br>OWASP Dependency-Check"]
        S7_OUT["Artifact: CVE report"]
    end

    subgraph PACKAGE_PHASE["Package Phase"]
        S8["8. BUILD JAR<br>mvn package"]
        S9["9. DOCKER BUILD<br>Multi-stage Dockerfile"]
    end

    subgraph SCAN_PHASE["Container Scan"]
        S10["10. TRIVY SCAN<br>HIGH + CRITICAL"]
        S10_OUT["SARIF to GitHub Security"]
    end

    subgraph PUSH_PHASE["Push to Registry"]
        S11_COND{"Branch = main?"}
        S11A["11a. OIDC Auth<br>GitHub JWT to AWS STS"]
        S11B["11b. ECR Login"]
        S11C["11c. Docker Push<br>SHA + latest tags"]
    end

    subgraph DISPATCH_PHASE["Trigger CD"]
        S12["12. repository-dispatch<br>payload: image_tag"]
    end

    T1 --> S1 --> S2 --> S3 --> S4
    S4 --> S4_OUT
    S4 --> S5
    S5_IN --> S5
    S5 --> S6 --> S7
    S7 --> S7_OUT
    S7 --> S8 --> S9 --> S10
    S10 --> S10_OUT
    S10 --> S11_COND
    S11_COND -->|"Yes"| S11A --> S11B --> S11C --> S12
    S11_COND -->|"No - PR only"| STOP["CI Complete<br>No push or deploy"]
```

---

## 6. CD Pipeline & GitOps Flow

```mermaid
sequenceDiagram
    participant CI as GitHub Actions CI
    participant CD as GitHub Actions CD
    participant MRepo as Manifest Repo
    participant ArgoCD as ArgoCD Controller
    participant K8s as EKS API Server
    participant ECR as Amazon ECR
    participant Pods as App Pods

    CI->>CD: 1. repository_dispatch<br>payload: image_tag=abc123

    Note over CD,MRepo: CD Workflow
    CD->>MRepo: 2. git clone (PAT auth)
    CD->>CD: 3. sed update image tag
    CD->>MRepo: 4. git commit + push

    Note over ArgoCD,Pods: GitOps Sync
    MRepo-->>ArgoCD: 5. Detect Git change<br>3 min poll
    ArgoCD->>ArgoCD: 6. Compare desired vs live
    ArgoCD->>K8s: 7. kubectl apply
    K8s->>K8s: 8. Create new ReplicaSet
    K8s->>ECR: 9. Pull image via VPC Endpoint
    ECR-->>K8s: 10. Image layers
    K8s->>Pods: 11. Start new pod
    Pods->>Pods: 12. Readiness probe OK
    K8s->>K8s: 13. Drain old pod
    K8s-->>ArgoCD: 14. Rollout complete

    Note over CI,Pods: Total: push to live in 9-12 minutes
```

---

## 7. Security Architecture — Defense in Depth

```mermaid
graph TB
    subgraph L1["Layer 1: Edge DNS + TLS"]
        R53_S["Route53 DNS Resolution"]
        ACM_S["ACM Certificate<br>TLS 1.3"]
    end

    subgraph L2["Layer 2: Firewall WAF v2"]
        WAF_R1["Rule 1: Rate Limit<br>2000 req per 5 min"]
        WAF_R2["Rule 2: OWASP Rules"]
        WAF_R3["Rule 3: SQL Injection"]
        WAF_R4["Rule 4: Known Bad Inputs<br>Log4j, SSRF, path traversal"]
        WAF_RESULT{"Pass All Rules?"}
        WAF_R1 --> WAF_RESULT
        WAF_R2 --> WAF_RESULT
        WAF_R3 --> WAF_RESULT
        WAF_R4 --> WAF_RESULT
        WAF_RESULT -->|"BLOCKED"| WAF_403["403 Forbidden"]
    end

    subgraph L3["Layer 3: API Authentication"]
        APIGW_S["API Gateway v2"]
        COG_AUTH["Cognito JWT Authorizer<br>signature, exp, aud, iss"]
        AUTH_RESULT{"Valid JWT?"}
        APIGW_S --> COG_AUTH --> AUTH_RESULT
        AUTH_RESULT -->|"INVALID"| AUTH_401["401 Unauthorized"]
    end

    subgraph L4["Layer 4: Transport ALB"]
        VPCLINK["VPC Link - Private"]
        ALB_S["ALB HTTPS:443<br>Target Group"]
        HEALTH["Health Check<br>GET /actuator/health"]
        ALB_S --> HEALTH
    end

    subgraph L5["Layer 5: Cluster EKS"]
        PRIVATE_EP["Private API Endpoint"]
        IRSA_S["IRSA Pod-level IAM"]
        IMDSV2["IMDSv2 Required"]
        KMS_S["KMS Secret Encryption"]
        NETPOL["Security Context<br>runAsNonRoot: true"]
    end

    subgraph L6["Layer 6: CI/CD Supply Chain"]
        OIDC_S["GitHub OIDC<br>No stored AWS keys"]
        SAST_S["SonarCloud SAST"]
        SCA_S["OWASP DC SCA"]
        TRIVY_S["Trivy Container Scan"]
        ECR_SCAN_S["ECR Scan on Push"]
    end

    R53_S --> ACM_S
    ACM_S --> WAF_R1
    WAF_RESULT -->|"ALLOWED"| APIGW_S
    AUTH_RESULT -->|"VALID"| VPCLINK --> ALB_S
    HEALTH -->|"Healthy"| PRIVATE_EP
```

---

## 8. Cognito Authentication Flow

```mermaid
sequenceDiagram
    participant User as User / Client App
    participant HUI as Cognito Hosted UI
    participant UP as Cognito User Pool
    participant APIGW as API Gateway v2
    participant ALB as Load Balancer
    participant POD as EKS Pod

    User->>HUI: 1. Navigate to login page
    User->>HUI: 2. Enter email + password
    HUI->>UP: 3. Validate credentials

    alt Invalid Credentials
        UP-->>HUI: 4a. Error message
        HUI-->>User: Show error
    end

    alt MFA Enabled
        UP-->>HUI: 4b. MFA challenge
        User->>HUI: Submit MFA code
        HUI->>UP: Verify MFA
    end

    UP-->>HUI: 5. Auth success
    HUI-->>User: 6. Redirect with tokens:<br>AccessToken, IdToken, RefreshToken

    User->>APIGW: 7. GET /api/data<br>Authorization: Bearer JWT
    APIGW->>APIGW: 8. Validate JWT

    alt Token Invalid
        APIGW-->>User: 9a. 401 Unauthorized
    end

    APIGW->>ALB: 9b. Forward via VPC Link
    ALB->>POD: 10. Route to healthy pod
    POD-->>ALB: 11. Response 200
    ALB-->>APIGW: 12. Forward response
    APIGW-->>User: 13. Response 200 + data
```

---

## 9. Request Traffic Flow — Edge to Pod

```mermaid
graph LR
    subgraph EDGE["Internet Edge"]
        USER_R["User Browser"]
    end

    subgraph DNS_LAYER["DNS"]
        R53_R["Route53<br>app.yourdomain.com<br>Alias to ALB"]
    end

    subgraph WAF_LAYER["WAF"]
        WAF_R["WAF v2<br>4 rule groups"]
    end

    subgraph LB_LAYER["Load Balancing"]
        ALB_HTTPS["ALB :443<br>TLS termination"]
        ALB_FORWARD["Forward Action"]
        ALB_TG["Target Group<br>Type: IP"]
    end

    subgraph EKS_LAYER["Private EKS"]
        POD_1["Pod AZ-a<br>10.0.101.x:8080"]
        POD_2["Pod AZ-b<br>10.0.102.x:8080"]
    end

    USER_R -->|"HTTPS"| R53_R -->|"Alias"| WAF_R -->|"Pass"| ALB_HTTPS
    ALB_HTTPS --> ALB_FORWARD --> ALB_TG
    ALB_TG -->|"Round Robin"| POD_1
    ALB_TG -->|"Round Robin"| POD_2
```

---

## 10. VPC Endpoint Connectivity

```mermaid
graph TB
    subgraph PRIVATE_SUBNET["Private Subnet - EKS Node"]
        POD_V["Application Pod"]
        KUBELET["Kubelet"]
        DOCKER_V["Container Runtime"]
    end

    subgraph VPCE_LAYER["VPC Endpoints"]
        ECR_API_V["ECR API<br>Interface Endpoint"]
        ECR_DKR_V["ECR Docker<br>Interface Endpoint"]
        S3_GW_V["S3 Gateway<br>FREE"]
        STS_V["STS<br>Interface Endpoint"]
        CW_V["CloudWatch Logs<br>Interface Endpoint"]
        EKS_V["EKS API<br>Interface Endpoint"]
    end

    subgraph AWS_SVC["AWS Services"]
        ECR_SVC_V["Amazon ECR"]
        S3_SVC_V["Amazon S3"]
        STS_SVC_V["AWS STS"]
        CW_SVC_V["CloudWatch"]
        EKS_SVC_V["EKS Control Plane"]
    end

    DOCKER_V -->|"docker pull"| ECR_API_V --> ECR_SVC_V
    DOCKER_V -->|"image layers"| ECR_DKR_V --> ECR_SVC_V
    DOCKER_V -->|"layer blobs"| S3_GW_V --> S3_SVC_V
    KUBELET -->|"IRSA auth"| STS_V --> STS_SVC_V
    KUBELET -->|"logs"| CW_V --> CW_SVC_V
    KUBELET -->|"API calls"| EKS_V --> EKS_SVC_V
```

---

## 11. Terraform Resource Dependency Graph

```mermaid
graph TB
    VPC_T["aws_vpc"]
    PUB_SUB["aws_subnet.public x3"]
    PRIV_SUB["aws_subnet.private x3"]
    IGW_T["aws_internet_gateway"]
    NAT_T["aws_nat_gateway"]
    VPCE_T["aws_vpc_endpoint x6"]
    SG_BASTION["sg: bastion"]
    SG_ALB["sg: alb"]
    SG_EKS_C["sg: eks_cluster"]
    SG_EKS_N["sg: eks_nodes"]
    KMS_T["aws_kms_key"]
    IAM_CLUSTER["iam: eks_cluster"]
    IAM_NODES["iam: eks_nodes"]
    EKS_T["aws_eks_cluster"]
    EKS_NG["aws_eks_node_group"]
    OIDC_P["iam_oidc: eks"]
    IAM_LBC["iam: alb_controller"]
    HELM_LBC["helm: aws_lb_controller"]
    HELM_ARGO["helm: argocd"]
    ALB_T["aws_lb"]
    ALB_TG["aws_lb_target_group"]
    ALB_LIS["aws_lb_listener"]
    WAF_T["aws_wafv2_web_acl"]
    WAF_ASSOC["waf_association"]
    R53_Z["aws_route53_zone"]
    ACM_T["aws_acm_certificate"]
    R53_REC["aws_route53_record"]
    COG_T["cognito_user_pool"]
    COG_C["cognito_client"]
    APIGW_T["apigatewayv2_api"]
    APIGW_VL["apigatewayv2_vpc_link"]
    APIGW_AUTH["apigatewayv2_authorizer"]
    ECR_T["aws_ecr_repository"]
    GH_OIDC["iam_oidc: github"]
    GH_ROLE["iam: github_actions"]
    BASTION_T["aws_instance: bastion"]

    VPC_T --> PUB_SUB
    VPC_T --> PRIV_SUB
    VPC_T --> IGW_T
    PUB_SUB --> NAT_T
    VPC_T --> VPCE_T
    VPC_T --> SG_BASTION --> BASTION_T
    VPC_T --> SG_ALB --> ALB_T
    VPC_T --> SG_EKS_C
    VPC_T --> SG_EKS_N
    IAM_CLUSTER --> EKS_T
    SG_EKS_C --> EKS_T
    PRIV_SUB --> EKS_T
    KMS_T --> EKS_T
    EKS_T --> EKS_NG
    IAM_NODES --> EKS_NG
    SG_EKS_N --> EKS_NG
    EKS_T --> OIDC_P --> IAM_LBC --> HELM_LBC
    EKS_T --> HELM_ARGO
    PUB_SUB --> ALB_T --> ALB_TG --> ALB_LIS
    ACM_T --> ALB_LIS
    WAF_T --> WAF_ASSOC
    ALB_T --> WAF_ASSOC
    R53_Z --> ACM_T
    R53_Z --> R53_REC
    ALB_T --> APIGW_VL --> APIGW_T
    COG_T --> COG_C
    COG_T --> APIGW_AUTH --> APIGW_T
    ECR_T --> GH_ROLE
    GH_OIDC --> GH_ROLE
```

---

## 12. Component Summary

| Category        | Component       | Technology     | Key Details                   |
| :-------------- | :-------------- | :------------- | :---------------------------- |
| **CI**    | Build & Test    | GitHub Actions | Java 17, Maven, JaCoCo        |
| **CI**    | SAST            | SonarCloud     | Bugs, vulns, smells, coverage |
| **CI**    | SCA             | OWASP DC       | NVD CVE database              |
| **CI**    | Container Scan  | Trivy          | HIGH + CRITICAL               |
| **CI**    | Registry Push   | ECR            | OIDC auth, scan-on-push       |
| **CI**    | AWS Auth        | GitHub OIDC    | Keyless, 15-min temp creds    |
| **CD**    | Manifest Update | GitHub Actions | sed image tag, git push       |
| **CD**    | Deployment      | ArgoCD         | Auto-sync, self-heal, prune   |
| **Infra** | Compute         | EKS private    | Multi-AZ, KMS, IMDSv2         |
| **Infra** | Networking      | VPC            | 3 pub + 3 priv + 6 VPC EP     |
| **Infra** | Load Balancing  | ALB            | HTTPS, health checks          |
| **Infra** | Firewall        | WAF v2         | OWASP + SQLi + rate limit     |
| **Infra** | API             | API Gateway v2 | VPC Link, throttling          |
| **Infra** | DNS             | Route53        | ACM wildcard cert             |
| **Infra** | Auth            | Cognito        | JWT, MFA, hosted UI           |
| **Infra** | Registry        | ECR            | Lifecycle, scan-on-push       |
| **Infra** | IaC             | Terraform      | ~60 resources                 |
| **Infra** | Admin           | Bastion EC2    | t3.micro, kubectl             |

---

## Monthly Cost: ~$235 (GitHub Actions + SonarCloud = Free)
