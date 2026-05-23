# Architecture — AWS IoT Greengrass v2 PoC

**Author:** Pushparaj Naik  
**Date:** May 2026  
**Version:** 1.0

---

## 1. What is AWS IoT Greengrass?

**AWS IoT Greengrass** is an open-source **edge runtime and cloud service** from AWS that brings cloud intelligence to edge devices. It allows IoT devices to collect, process, and act on data **locally** — at the point of generation — while seamlessly integrating with AWS cloud services for management, analytics, and long-term storage.

### Why Does It Exist?

Traditional IoT architectures require **every data point** to travel to the cloud for processing. This is problematic for three fundamental reasons:

1. **Latency** — A temperature sensor detecting a fire can't wait 200ms for a cloud round-trip to trigger a sprinkler
2. **Connectivity** — Remote sites (oil rigs, wind farms, rural factories) have unreliable internet
3. **Cost** — Sending 10,000 sensor readings/second to the cloud is prohibitively expensive

**IoT Greengrass solves all three** by running application logic directly on the edge device:

```mermaid
graph TB
    subgraph TRADITIONAL["❌ Traditional IoT (Cloud-Only)"]
        direction LR
        T_SENSOR["🌡️ Sensor"] -->|"ALL raw data<br/>10,000 msgs/sec"| T_CLOUD["☁️ Cloud Processing"]
        T_CLOUD -->|"decision after<br/>200ms delay"| T_SENSOR
    end

    subgraph GREENGRASS["✅ IoT Greengrass (Edge + Cloud)"]
        direction LR
        G_SENSOR["🌡️ Sensor"] -->|"raw data"| G_EDGE["🖥️ Greengrass<br/>(Edge Processing)"]
        G_EDGE -->|"aggregated summary<br/>only 17 msgs/min"| G_CLOUD["☁️ Cloud Analytics"]
        G_EDGE -->|"instant local<br/>decision <10ms"| G_SENSOR
    end

    style TRADITIONAL fill:#ffebee,stroke:#c62828
    style GREENGRASS fill:#e8f5e9,stroke:#2e7d32
    style G_EDGE fill:#FF9900,color:black,stroke:#232F3E
```

### Key Components of IoT Greengrass v2

| Component | Purpose | Where It Runs |
|-----------|---------|---------------|
| **Greengrass Nucleus** | Core runtime — manages component lifecycle, IPC, deployments | Edge device |
| **Custom Components** | Your application code (Python, Java, Node.js) | Edge device |
| **MQTT Bridge** | Routes messages between local MQTT and AWS IoT Core | Edge device |
| **Log Manager** | Uploads component logs to CloudWatch | Edge device |
| **Secret Manager** | Securely provides secrets from AWS Secrets Manager | Edge device |
| **Token Exchange Service** | Provides temporary AWS credentials to components | Edge device → Cloud |
| **IoT Core** | Managed MQTT broker, device registry, rules engine | Cloud |
| **Component Registry** | Stores component recipes and artifacts | Cloud |
| **Fleet Deployments** | Manages software deployments to device groups | Cloud |

### How IoT Core and Greengrass Work Together

```mermaid
graph TB
    subgraph "Edge Device"
        NUCLEUS["Greengrass Nucleus"]
        COMP["Custom Components<br/>(Python)"]
        MQTT_L["Local MQTT Broker"]
        TES_L["TES Client"]
        NUCLEUS --> COMP
        COMP <-->|"pub/sub"| MQTT_L
    end

    subgraph "AWS Cloud"
        IOTCORE["AWS IoT Core"]
        REG["Thing Registry<br/>+ Certificates"]
        RULES["Rules Engine"]
        DEPLOY["Fleet Deployment<br/>Manager"]
        TES_C["Token Exchange<br/>Service"]
        COMPSTORE["Component<br/>Registry (S3)"]
    end

    MQTT_L <-->|"MQTT over TLS 1.2<br/>X.509 mutual auth"| IOTCORE
    TES_L -->|"Get temp AWS creds"| TES_C
    NUCLEUS -->|"Check for updates"| DEPLOY
    DEPLOY -->|"Download components"| COMPSTORE
    IOTCORE --> RULES
    REG -.->|"authenticates"| IOTCORE

    style NUCLEUS fill:#FF9900,color:black
    style IOTCORE fill:#232F3E,color:#FF9900
```

> **Summary:** IoT Core handles cloud-side device management, authentication, and data routing. Greengrass handles edge-side processing, offline resilience, and local intelligence. They are **complementary services** that form a complete IoT platform.

---

## 2. Architecture Overview

This architecture implements a **hub-and-spoke IoT model** where edge devices at customer sites (spokes) securely publish telemetry data to AWS IoT Core (hub). The data flows through a serverless processing pipeline for storage, analytics, and alerting.

### Design Principles
- **Edge-first processing** — Filter and aggregate at the edge, not in the cloud
- **Security by design** — Zero-trust model with per-device certificates and least-privilege policies
- **Serverless backend** — No servers to manage; IoT Rules + Lambda + managed databases
- **Infrastructure as Code** — Every resource defined in Terraform, no ClickOps

---

## 3. Component Architecture

### 3.1 End-to-End Architecture

```mermaid
graph TB
    subgraph EDGE["🏭 Edge Layer — Customer Sites"]
        direction TB
        subgraph M["📍 Site Mumbai"]
            GG1["Greengrass Core"]
            SC1["Sensor Collector"]
            TP1["Telemetry Processor"]
            SC1 -->|"raw"| TP1
            TP1 --> GG1
        end
        subgraph B["📍 Site Bangalore"]
            GG2["Greengrass Core"]
            SC2["Sensor Collector"]
            TP2["Telemetry Processor"]
            SC2 -->|"raw"| TP2
            TP2 --> GG2
        end
        subgraph D["📍 Site Delhi"]
            GG3["Greengrass Core"]
            SC3["Sensor Collector"]
            TP3["Telemetry Processor"]
            SC3 -->|"raw"| TP3
            TP3 --> GG3
        end
    end

    subgraph CLOUD["☁️ AWS Cloud (us-east-1)"]
        IOT["AWS IoT Core<br/>MQTT Broker + Device Registry<br/>+ Device Shadows"]

        subgraph RULES["🔄 IoT Rules Engine"]
            R1["Archive Rule<br/>SELECT * → S3"]
            R2["Analytics Rule<br/>SELECT metrics → Timestream"]
            R3["Temp Alert Rule<br/>WHERE temp > 35°C"]
            R4["Humidity Alert Rule<br/>WHERE humidity > 85%"]
        end

        subgraph STORE["💾 Storage"]
            S3["Amazon S3<br/>Raw Archive<br/>Std → IA → Glacier"]
            TS["Amazon Timestream<br/>Time-Series<br/>24h hot / 365d warm"]
        end

        subgraph ALERT["🚨 Alerting"]
            LAM["Lambda<br/>Alert Processor"]
            SNS["Amazon SNS<br/>Email Notifications"]
        end

        subgraph OBS["📊 Observability"]
            CW["CloudWatch<br/>Dashboard + Alarms"]
            LOG["CloudWatch Logs"]
        end

        subgraph SEC["🔐 Security"]
            KMS["AWS KMS — CMK"]
            IAM_R["IAM Roles<br/>TES / Rules / Lambda"]
            CERTS["X.509 Certificates"]
        end
    end

    GG1 ==>|"MQTT/TLS"| IOT
    GG2 ==>|"MQTT/TLS"| IOT
    GG3 ==>|"MQTT/TLS"| IOT
    IOT --> R1 & R2 & R3 & R4
    R1 --> S3
    R2 --> TS
    R3 & R4 --> LAM
    LAM --> SNS
    IOT -.-> CW
    KMS -.->|"encrypts"| S3 & TS & SNS
    CERTS -.->|"auth"| IOT

    style EDGE fill:#e8f5e9,stroke:#2e7d32
    style CLOUD fill:#e3f2fd,stroke:#1565c0
    style IOT fill:#FF9900,color:white,stroke:#232F3E
    style RULES fill:#fff3e0,stroke:#ef6c00
    style STORE fill:#f3e5f5,stroke:#7b1fa2
    style SEC fill:#fce4ec,stroke:#c62828
    style ALERT fill:#fff8e1,stroke:#f9a825
```

### 3.2 Edge Device Architecture

```mermaid
graph TB
    subgraph DEVICE["Greengrass Core Device (Linux / EC2 / Raspberry Pi)"]
        subgraph NUCLEUS["Greengrass Nucleus v2.9+"]
            subgraph CUSTOM["Custom Components"]
                SC["📡 Sensor Collector<br/>(Python)<br/>Generates: temp, humidity, pressure"]
                TP["⚙️ Telemetry Processor<br/>(Python)<br/>Aggregate, filter, anomaly detect"]
                SC -->|"raw readings"| TP
            end

            subgraph BUILTIN["Built-in Components"]
                BRIDGE["🔗 MQTT Bridge<br/>Local ↔ IoT Core"]
                LOGMGR["📋 Log Manager<br/>→ CloudWatch Logs"]
                SECMGR["🔐 Secret Manager<br/>← AWS Secrets Manager"]
                SPOOLER["💿 Disk Spooler<br/>Offline message buffer"]
            end

            TP -->|"processed data"| BRIDGE
        end
    end

    BRIDGE ==>|"MQTT over TLS 1.2<br/>Port 8883<br/>X.509 mutual auth"| IOTCORE["☁️ AWS IoT Core"]
    LOGMGR -->|"component logs"| CWLOGS["📈 CloudWatch Logs"]

    style DEVICE fill:#f5f5f5,stroke:#424242
    style NUCLEUS fill:#fff3e0,stroke:#FF9900
    style CUSTOM fill:#e3f2fd,stroke:#1565c0
    style BUILTIN fill:#e8f5e9,stroke:#2e7d32
    style IOTCORE fill:#FF9900,color:white
```

---

## 4. Data Flow

### 4.1 Telemetry Ingestion Flow

```mermaid
sequenceDiagram
    participant SC as 🌡️ Sensor Collector
    participant TP as ⚙️ Telemetry Processor
    participant MB as 🔗 MQTT Bridge
    participant IOT as ☁️ IoT Core
    participant RE as 🔄 Rules Engine
    participant S3 as 📦 S3
    participant TS as 📊 Timestream
    participant LAM as ⚡ Lambda
    participant SNS as 📧 SNS

    rect rgb(232, 245, 233)
        Note over SC,TP: Edge Layer (Greengrass Core Device)
        loop Every 10 seconds
            SC->>TP: {temp: 31.5, humidity: 72.0, pressure: 1013.2}
        end
        Note over TP: Aggregate 60s window<br/>Filter noise<br/>Detect anomalies
        TP->>MB: Processed telemetry payload
    end

    rect rgb(227, 242, 253)
        Note over IOT,SNS: Cloud Layer (AWS)
        MB->>IOT: MQTT over TLS 1.2 (X.509 mTLS)<br/>Topic: dt/iot-greengrass/{site}/telemetry
        IOT->>RE: Evaluate 4 SQL rules

        par Rule 1 — Archive
            RE->>S3: Store raw JSON<br/>s3://bucket/telemetry/{site}/{date}/{uuid}.json
        and Rule 2 — Analytics
            RE->>TS: Write time-series record<br/>dimensions: device_id, site
        and Rule 3 — Temperature Alert (if temp > 35°C)
            RE->>LAM: Invoke with enriched payload
            LAM->>SNS: Formatted alert notification
            SNS-->>SNS: 📧 Email to operator
        end
    end
```

### 3.2 MQTT Topic Hierarchy

```
dt/iot-greengrass/
├── site-mumbai/
│   ├── telemetry          ← Raw sensor readings (published by device)
│   ├── aggregate          ← Aggregated data (published by edge processor)
│   ├── alert              ← Local anomaly alerts
│   └── command            ← Commands from cloud (subscribed by device)
├── site-bangalore/
│   ├── telemetry
│   ├── aggregate
│   ├── alert
│   └── command
└── site-delhi/
    ├── telemetry
    ├── aggregate
    ├── alert
    └── command
```

**Topic Naming Convention:** `dt/{project}/{site}/{type}`
- `dt` = data/telemetry prefix (AWS best practice)
- `{project}` = project name for namespace isolation
- `{site}` = customer site identifier
- `{type}` = message type (telemetry, aggregate, alert, command)

---

## 5. Terraform Module Architecture

```mermaid
graph TB
    subgraph ROOT["Root Module (main.tf)"]
        direction TB
        subgraph TIER1["Tier 1 — Independent"]
            direction LR
            STORAGE["📦 storage<br/>S3 Bucket + Timestream"]
            IOTCORE["📡 iot_core<br/>Things ×3, Certs ×3<br/>Policy, Thing Group"]
        end

        subgraph TIER2["Tier 2 — Depends on Tier 1"]
            direction LR
            MONITORING["📊 monitoring<br/>SNS, Alarms, Dashboard"]
            IAM["🔐 iam<br/>KMS, TES Role<br/>Rules Role, Lambda Role"]
        end

        subgraph TIER3["Tier 3 — Depends on Tier 1 + 2"]
            direction LR
            LAMBDA["⚡ lambda<br/>Alert Processor<br/>+ IoT Invoke Permission"]
            GREENGRASS["🌿 iot_greengrass<br/>Role Alias (TES)<br/>TES Policy, CW Logs"]
        end

        subgraph TIER4["Tier 4 — Depends on All"]
            RULES["🔄 iot_rules<br/>S3 Rule, TS Rule<br/>Temp Alert, Humidity Alert"]
        end
    end

    STORAGE --> IAM
    IOTCORE --> GREENGRASS
    MONITORING --> LAMBDA
    IAM --> LAMBDA & GREENGRASS
    STORAGE & LAMBDA & IAM --> RULES

    style ROOT fill:#f5f5f5,stroke:#616161
    style TIER1 fill:#e3f2fd,stroke:#1565c0
    style TIER2 fill:#fff3e0,stroke:#ef6c00
    style TIER3 fill:#e8f5e9,stroke:#2e7d32
    style TIER4 fill:#fce4ec,stroke:#c62828
    style IOTCORE fill:#FF9900,color:white
```

---

## 6. Network Architecture

### 6.1 Connectivity Model

```mermaid
graph LR
    subgraph SITE["🏭 Customer Site"]
        GG["Greengrass Core<br/>IP: Dynamic<br/>OS: Linux"]
        CERT["📜 X.509 Cert<br/>🔑 Private Key"]
    end

    subgraph INTERNET["🌐 Internet"]
        TLS["TLS 1.2 Tunnel<br/>Port 8883<br/>MQTT over TLS"]
    end

    subgraph AWS["☁️ AWS Cloud"]
        ATS["IoT Core ATS Endpoint<br/>*.iot.us-east-1.amazonaws.com<br/>Port 8883"]
    end

    GG -->|"Client Certificate"| TLS
    CERT -.->|"mutual auth"| TLS
    TLS -->|"MQTT CONNECT<br/>clientId = ThingName"| ATS

    style GG fill:#FF9900,color:black
    style ATS fill:#232F3E,color:#FF9900
    style TLS fill:#e3f2fd,stroke:#1565c0
```

- **Protocol:** MQTT over TLS 1.2 (port 8883)
- **Authentication:** X.509 mutual TLS (certificate-based, no passwords)
- **Endpoint:** ATS (Amazon Trust Services) endpoint for improved certificate management
- **QoS:** Level 1 (At Least Once) — ensures message delivery

---

## 7. Scalability Considerations

| Dimension | Current PoC | Production Scale |
|-----------|-------------|-----------------|
| **Sites** | 3 (Mumbai, Bangalore, Delhi) | 100+ sites via fleet provisioning |
| **Devices per site** | 1 Greengrass Core | Multiple cores + client devices |
| **Message rate** | 6 msgs/min/device | Up to 100 msgs/sec/device |
| **Storage** | S3 + Timestream | Add Kinesis for high-throughput buffering |
| **Processing** | Lambda (async) | Step Functions for complex workflows |

### Scaling Path
1. **Fleet Provisioning** — Replace manual cert creation with `aws_iot_provisioning_template`
2. **Kinesis Data Streams** — Buffer high-volume telemetry before S3/Timestream
3. **IoT Analytics** — Advanced analytics pipeline for ML model training
4. **IoT SiteWise** — Industrial equipment monitoring with asset modeling

---

## 8. Cost Estimation (Dev Environment)

| Service | Monthly Cost (approx.) |
|---------|----------------------|
| IoT Core (3 devices, 6 msgs/min) | ~$0.50 |
| Timestream (6h memory, 30d magnetic) | ~$5.00 |
| S3 (< 1 GB telemetry/month) | ~$0.10 |
| Lambda (< 1000 invocations/month) | ~$0.00 (free tier) |
| CloudWatch (dashboard + logs) | ~$3.00 |
| SNS (email notifications) | ~$0.00 (free tier) |
| KMS (1 key) | $1.00 |
| **Total** | **~$9.60/month** |
