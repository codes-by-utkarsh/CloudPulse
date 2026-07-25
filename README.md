<div align="center">

<img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
<img src="https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" />
<img src="https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white" />
<img src="https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" />
<img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
<img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white" />

# ☁️ CloudPulse

### Production-Grade Kubernetes Observability & Reliability Platform

*Monitors the **BodhGanga** Java Spring Boot application with Prometheus, Grafana, and Alertmanager — following SRE best practices.*

</div>

---

## 📑 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Data Flow](#-data-flow)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Quickstart Guide](#-quickstart-guide)
  - [Phase 1 – Prepare BodhGanga](#phase-1--prepare-bodhganga)
  - [Phase 2 – Bootstrap the Cluster](#phase-2--bootstrap-the-cluster)
  - [Phase 3 – Deploy BodhGanga](#phase-3--deploy-bodhganga)
  - [Phase 4 – Deploy the Observability Stack](#phase-4--deploy-the-observability-stack)
  - [Phase 5 – Alerting & Dashboards](#phase-5--alerting--dashboards)
- [Grafana Dashboards](#-grafana-dashboards)
- [Alert Rules Reference](#-alert-rules-reference)
- [Port Forwarding Reference](#-port-forwarding-reference)
- [SRE Concepts Applied](#-sre-concepts-applied)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Kubernetes Cluster (Minikube / K3s)                   │
│                                                                             │
│  ┌──────────────────────────────────────────┐                               │
│  │         Namespace: bodhganga             │                               │
│  │                                          │                               │
│  │   ┌──────────┐  ┌──────────┐  ┌───────┐ │                               │
│  │   │ BodhGanga│  │BodhGanga │  │Bodhga-│ │  <- 3 Replicas (HA)           │
│  │   │  Pod 1   │  │  Pod 2   │  │nga    │ │                               │
│  │   │ :8080    │  │ :8080    │  │Pod 3  │ │                               │
│  │   │ :9090(m) │  │ :9090(m) │  │:9090  │ │  <- Actuator/Prometheus       │
│  │   └────┬─────┘  └────┬─────┘  └──┬────┘ │                               │
│  │        └─────────────┴───────────┘       │                               │
│  │                    │                     │                               │
│  │           ┌────────▼────────┐            │                               │
│  │           │  bodhganga-svc  │            │                               │
│  │           │  ClusterIP      │            │                               │
│  │           │  port 80/9090   │            │                               │
│  │           └────────┬────────┘            │                               │
│  └────────────────────│────────────────────-┘                               │
│                       │ scrape /actuator/prometheus every 30s               │
│  ┌────────────────────▼─────────────────────────────────────────────────┐   │
│  │                   Namespace: monitoring                              │   │
│  │                                                                      │   │
│  │  ┌─────────────────────┐     ┌──────────────────┐                   │   │
│  │  │    Prometheus        │────▶│  Alertmanager    │──▶ Discord/Slack  │   │
│  │  │  (stores metrics)    │     │  (routes alerts) │                   │   │
│  │  └──────────┬──────────┘     └──────────────────┘                   │   │
│  │             │                                                        │   │
│  │  ┌──────────▼──────────┐     ┌──────────────────┐                   │   │
│  │  │      Grafana         │     │  kube-state-     │                   │   │
│  │  │   (dashboards)       │     │  metrics +       │                   │   │
│  │  └─────────────────────┘     │  node-exporter   │                   │   │
│  │                              └──────────────────┘                   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Prometheus Operator (CRD Controller)                                │   │
│  │   - Watches: ServiceMonitor, PrometheusRule, AlertmanagerConfig CRDs  │   │
│  │   - Auto-configures Prometheus scraping and alert evaluation         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow

```
BodhGanga Spring Boot App
       │
       │  Micrometer SDK instruments HTTP requests,
       │  JVM heap, GC, thread pools, custom metrics
       │
       ▼
 /actuator/prometheus  (port 9090, internal)
       │
       │  Prometheus Operator reads ServiceMonitor CRD
       │  Automatically adds scrape job every 30 seconds
       │
       ▼
  Prometheus TSDB  (15-day rolling time-series store)
       │
       ├──▶  Alert Evaluation Engine
       │         │  PrometheusRule CRD defines conditions
       │         │  e.g., pod down > 1m, CPU > 80%
       │         ▼
       │    Alertmanager
       │         │  AlertmanagerConfig CRD routes by severity
       │         ▼
       │    Discord / Slack Webhook
       │         (instant notification with runbook link)
       │
       └──▶  Grafana (PromQL queries → live dashboards)
                  │
                  ▼
             Engineer Browser  (port-forward 3000)
```

---

## ✨ Features

| Feature | Description | SRE Concept |
|---|---|---|
| **Cluster Health Monitoring** | Node CPU, memory, disk — via Node Exporter | Capacity Planning |
| **Application Performance Monitoring** | HTTP latency (p50/p95/p99), throughput, error rate | SLI Measurement |
| **JVM Deep Dive** | Heap usage, GC pauses, thread count, connection pools | MELT Observability |
| **Automated Incident Notifications** | Alerts routed to Discord/Slack within 1 minute of breach | Incident Management |
| **Zero-downtime Deployments** | Rolling update strategy with PodDisruptionBudget | Change Management |
| **High Availability** | 3 replicas + topologySpreadConstraints | Fault Tolerance |
| **Auto-healing** | Liveness + Readiness + Startup probes with auto-restart | Self-healing Systems |
| **SLO-aligned Alerting** | Error rate > 5% and p99 latency > 2s alerts | Error Budget Burn |
| **Security Hardened** | Non-root containers, readOnlyRootFilesystem, dropped capabilities | Defence in Depth |
| **GitOps Ready** | All config is declarative YAML; apply via CI/CD | Infrastructure as Code |

---

## 📁 Project Structure

```
CloudPulse/
├── bodhganga-app/                 # Java Spring Boot application
│   ├── src/main/resources/
│   │   └── application.yml        # Actuator & Micrometer config
│   ├── Dockerfile                 # Multi-stage production image
│   └── pom.xml                    # Maven – includes Micrometer + Actuator
│
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # bodhganga namespace
│   ├── Deployment.yaml            # 3 replicas, probes, resource limits
│   ├── Service.yaml               # ClusterIP + PodDisruptionBudget
│   ├── ServiceMonitor.yaml        # Prometheus auto-scrape config (CRD)
│   ├── PrometheusRule.yaml        # 8 alerting rules (CRD)
│   └── AlertmanagerConfig.yaml    # Discord/Slack routing (CRD)
│
├── helm/
│   └── prometheus-values.yaml     # kube-prometheus-stack Helm overrides
│
├── scripts/
│   ├── setup-cluster.sh           # Cluster bootstrap (Docker + k8s + Helm)
│   └── deploy-stack.sh            # Full stack deployment automation
│
└── README.md
```

---

## 🔧 Prerequisites

| Tool | Minimum Version | Purpose |
|---|---|---|
| Linux (Debian/Ubuntu) | 20.04+ | Host OS |
| Docker | 24.x | Container runtime |
| Minikube | 1.33+ | Local Kubernetes |
| kubectl | 1.29+ | Cluster management |
| Helm | 3.14+ | Package manager |
| Java | 17+ | BodhGanga runtime |
| Maven | 3.8+ | BodhGanga build |

> **Note for Windows users:** Use WSL2 (Ubuntu) to run the Bash scripts. Docker Desktop with WSL2 backend is recommended.

---

## 🚀 Quickstart Guide

### Phase 1 – Prepare BodhGanga

**Step 1.1 – Verify your `pom.xml` includes these dependencies:**

```xml
<!-- Spring Boot Actuator -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Micrometer Core -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
</dependency>

<!-- Micrometer Prometheus Registry -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    <scope>runtime</scope>
</dependency>
```

**Step 1.2 – Verify your `application.yml` exposes the Prometheus endpoint:**

The management server runs on port `9090` (separate from your app on `8080`). The endpoint `/actuator/prometheus` is exposed only on this internal management port — it is **never** accessible via the public Ingress.

**Step 1.3 – Test locally before containerizing:**

```bash
cd bodhganga-app
./mvnw spring-boot:run

# In a second terminal:
curl http://localhost:9090/actuator/prometheus | head -50
# You should see lines like: jvm_memory_used_bytes{...} 12345678
```

---

### Phase 2 – Bootstrap the Cluster

```bash
# Clone the repo
git clone https://github.com/your-org/cloudpulse.git
cd cloudpulse

# Make scripts executable
chmod +x scripts/setup-cluster.sh scripts/deploy-stack.sh

# Run bootstrap (Minikube – for local development)
sudo ./scripts/setup-cluster.sh

# OR for a VPS / production server (K3s):
sudo ./scripts/setup-cluster.sh --k3s

# Verify cluster is healthy
kubectl get nodes
# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.30.x
```

---

### Phase 3 – Deploy BodhGanga

```bash
# Step 3.1 – Point Docker CLI to Minikube's daemon
eval $(minikube docker-env)

# Step 3.2 – Build the BodhGanga Docker image
docker build -t bodhganga-app:1.0.0 bodhganga-app/

# Verify image is available inside Minikube
docker images | grep bodhganga

# Step 3.3 – Create the namespace
kubectl apply -f k8s/namespace.yaml

# Step 3.4 – Deploy the application
kubectl apply -f k8s/Deployment.yaml
kubectl apply -f k8s/Service.yaml

# Step 3.5 – Verify all 3 pods are Running
kubectl get pods -n bodhganga -w
# NAME                         READY   STATUS    RESTARTS   AGE
# bodhganga-6d4c9f7b9c-2xjqp   1/1     Running   0          45s
# bodhganga-6d4c9f7b9c-8mzkl   1/1     Running   0          45s
# bodhganga-6d4c9f7b9c-vp9dn   1/1     Running   0          45s

# Step 3.6 – Quick smoke test
kubectl port-forward svc/bodhganga-svc 8080:80 -n bodhganga &
curl http://localhost:8080/actuator/health
# {"status":"UP","components":{"liveness":{"status":"UP"},"readiness":{"status":"UP"}}}
```

---

### Phase 4 – Deploy the Observability Stack

```bash
# Step 4.1 – Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Verify repo is available
helm search repo prometheus-community/kube-prometheus-stack

# Step 4.2 – Install the full kube-prometheus-stack
# This installs: Prometheus Operator, Prometheus, Grafana, Alertmanager,
#                kube-state-metrics, node-exporter in one command.
helm upgrade --install cloudpulse-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/prometheus-values.yaml \
  --wait \
  --timeout 10m

# Step 4.3 – Verify all monitoring pods are Running
kubectl get pods -n monitoring
# NAME                                                      READY   STATUS    RESTARTS   AGE
# cloudpulse-grafana-xxx                                    3/3     Running   0          2m
# cloudpulse-kube-prome-operator-xxx                        1/1     Running   0          2m
# cloudpulse-prometheus-node-exporter-xxx                   1/1     Running   0          2m
# prometheus-cloudpulse-prometheus-kube-prome-prometheus-0  2/2     Running   0          90s
# alertmanager-cloudpulse-prometheus-kube-prome-alertmanager-0  2/2 Running  0          90s

# Step 4.4 – Apply the ServiceMonitor (tells Prometheus to scrape BodhGanga)
kubectl apply -f k8s/ServiceMonitor.yaml

# Verify the scrape target appears in Prometheus (wait ~1 min, then check):
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring &
# Open http://localhost:9091/targets and look for "bodhganga-svc"
```

---

### Phase 5 – Alerting & Dashboards

```bash
# Step 5.1 – Apply alert rules
kubectl apply -f k8s/PrometheusRule.yaml

# Verify rules are loaded by Prometheus
curl http://localhost:9091/api/v1/rules | jq '.data.groups[].name'

# Step 5.2 – Configure AlertmanagerConfig
# IMPORTANT: Edit k8s/AlertmanagerConfig.yaml first!
# Replace REPLACE_WITH_YOUR_CRITICAL_WEBHOOK_URL with your Discord webhook.
# How to get a Discord webhook:
#   Discord Server → Channel Settings → Integrations → Webhooks → New Webhook → Copy URL

nano k8s/AlertmanagerConfig.yaml   # or use your editor

kubectl apply -f k8s/AlertmanagerConfig.yaml

# Step 5.3 – Test alert routing (fire a test alert)
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring &

curl -X POST http://localhost:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"warning","service":"bodhganga"},
    "annotations": {"summary":"Test alert from CloudPulse"}
  }]'
# Check your Discord/Slack channel for the notification!
```

---

## 📊 Grafana Dashboards

### Accessing Grafana

```bash
# Port-forward Grafana to your local machine
kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring

# Open in browser:
# URL:      http://localhost:3000
# Username: admin
# Password: CloudPulse@2024!
```

### Recommended Dashboard IDs to Import

| Dashboard | Grafana ID | Description |
|---|---|---|
| **JVM (Micrometer)** | `4701` | ⭐ Best for Spring Boot — heap, GC, threads, HTTP |
| **Spring Boot Statistics** | `12900` | HTTP rate, error rate, latency, Tomcat |
| **Spring Boot 2.1 System Monitor** | `11378` | CPU, memory, disk from Micrometer |
| **Kubernetes Cluster Overview** | `7249` | Node health, pod counts, resource usage |
| **Kubernetes Pod Details** | `6781` | Per-pod CPU, memory, network |
| **Node Exporter Full** | `1860` | Deep hardware metrics for each node |
| **Alertmanager** | `9578` | Alert routing and notification status |

### How to Import a Dashboard

1. Open Grafana → **Dashboards** → **Import**
2. Enter the Dashboard ID (e.g., `4701`)
3. Click **Load**
4. Select **Prometheus** as the data source
5. Click **Import**

> 💡 **Recommended for BodhGanga**: Start with ID **`4701`** (JVM Micrometer). It shows exactly what your Spring Boot app is doing internally — heap usage, GC activity, active HTTP requests, and connection pool stats.

---

## 🚨 Alert Rules Reference

| Alert Name | Condition | Severity | For |
|---|---|---|---|
| `BodhGangaTargetDown` | Any BodhGanga pod unreachable | 🔴 critical | 1 min |
| `BodhGangaReplicasMissing` | Ready replicas < 3 | ⚠️ warning | 2 min |
| `BodhGangaHighErrorRate` | HTTP 5xx rate > 5% | 🔴 critical | 5 min |
| `BodhGangaHighLatency` | p99 latency > 2s | ⚠️ warning | 5 min |
| `HighNodeCpuUsage` | Node CPU > 80% | ⚠️ warning | 5 min |
| `HighNodeMemoryUsage` | Node memory > 85% | ⚠️ warning | 5 min |
| `LowDiskSpace` | Disk free < 15% | ⚠️ warning | 10 min |
| `BodhGangaJvmHeapHigh` | JVM heap > 85% | ⚠️ warning | 5 min |

---

## 🔌 Port Forwarding Reference

Run each command in a separate terminal tab:

```bash
# Grafana (Dashboards)
kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring
# → http://localhost:3000

# Prometheus (Query UI + Targets)
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring
# → http://localhost:9091

# Alertmanager (Alert routing status)
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring
# → http://localhost:9093

# BodhGanga App (direct access)
kubectl port-forward svc/bodhganga-svc 8080:80 -n bodhganga
# → http://localhost:8080

# BodhGanga Actuator (raw metrics)
kubectl port-forward svc/bodhganga-svc 9090:9090 -n bodhganga
# → http://localhost:9090/actuator/prometheus
```

---

## 🛡️ SRE Concepts Applied

### The Four Golden Signals (Implemented)

| Signal | How Measured | Alert |
|---|---|---|
| **Latency** | `http_server_requests_seconds` (p99) | `BodhGangaHighLatency` > 2s |
| **Traffic** | `rate(http_server_requests_seconds_count[5m])` | Dashboard only |
| **Errors** | 5xx / total request ratio | `BodhGangaHighErrorRate` > 5% |
| **Saturation** | JVM heap %, CPU %, memory % | Multiple alerts |

### SLI → SLO → Error Budget

The `application.yml` configures SLO histogram buckets at 50ms, 100ms, 200ms, 500ms, 1s, 2s. This lets you write PromQL queries like:

```promql
# SLI: % of requests completing within 500ms (your latency SLO target)
sum(rate(http_server_requests_seconds_bucket{le="0.5", namespace="bodhganga"}[5m]))
/
sum(rate(http_server_requests_seconds_count{namespace="bodhganga"}[5m]))
```

### Zero-Downtime Deployments

1. **Rolling Update** — `maxUnavailable: 1`, `maxSurge: 1`
2. **PodDisruptionBudget** — at least 2/3 pods always serving
3. **Readiness Probe** — pod only receives traffic when `/actuator/health/readiness` returns UP
4. **Graceful Shutdown** — Spring Boot drains in-flight requests (20s window)
5. **Startup Probe** — gives slow JVM startup up to 2 minutes without false-positive kills

---

## 🔍 Troubleshooting

### BodhGanga pods not starting

```bash
kubectl describe pod -n bodhganga -l app.kubernetes.io/name=bodhganga
kubectl logs -n bodhganga -l app.kubernetes.io/name=bodhganga --tail=100
```

### ServiceMonitor not being picked up by Prometheus

```bash
# Check Prometheus targets
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring
# Open: http://localhost:9091/targets — look for "bodhganga-svc"

# Check that the ServiceMonitor has the correct release label
kubectl get servicemonitor -n bodhganga -o yaml | grep "release:"
# Must match: release: cloudpulse-prometheus
```

### Alertmanager not sending notifications

```bash
# Check AlertmanagerConfig was loaded
kubectl get alertmanagerconfig -n bodhganga

# Check Alertmanager logs for webhook errors
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=50
```

### Minikube running out of resources

```bash
minikube stop
minikube delete
minikube start --cpus=6 --memory=8192 --disk-size=40g
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Commit your changes with a meaningful message
4. Push and open a Pull Request
5. All PRs must include updated documentation

---

<div align="center">

Built with ❤️ as part of the **CloudPulse SRE Platform**

</div>
