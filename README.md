<div align="center">

<img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
<img src="https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" />
<img src="https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white" />
<img src="https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" />
<img src="https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white" />
<img src="https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black" />
<img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
<img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white" />

# ☁️ CloudPulse

### Production-Grade Kubernetes Observability & Reliability Platform

*End-to-end monitoring for the **BodhGanga** full-stack application — Spring Boot 3.4.5 backend, React frontend, and MongoDB — built with Prometheus, Grafana, and Alertmanager following SRE best practices.*

</div>

---

## 📑 Table of Contents

- [About BodhGanga](#-about-bodhganga)
- [Architecture Overview](#-architecture-overview)
- [Data Flow](#-data-flow)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Deployment Guide](#-deployment-guide)
  - [Step 1 — Bootstrap the Cluster](#step-1--bootstrap-the-cluster)
  - [Step 2 — Configure Secrets](#step-2--configure-secrets)
  - [Step 3 — Build Docker Images](#step-3--build-docker-images)
  - [Step 4 — Deploy BodhGanga Stack](#step-4--deploy-bodhganga-stack)
  - [Step 5 — Deploy Observability Stack](#step-5--deploy-observability-stack)
  - [Step 6 — Configure Alerts](#step-6--configure-alerts)
  - [Step 7 — Access Grafana](#step-7--access-grafana)
- [Port Reference](#-port-reference)
- [Grafana Dashboards](#-grafana-dashboards)
- [Alert Rules Reference](#-alert-rules-reference)
- [SRE Concepts Applied](#-sre-concepts-applied)
- [Troubleshooting](#-troubleshooting)

---

## 🎓 About BodhGanga

**BodhGanga** is a production-grade educational platform. CloudPulse adds a complete observability and reliability layer on top of it.

| Component | Technology | Port |
|---|---|---|
| **Backend API** | Spring Boot 3.4.5 · Java 17 · MongoDB · Spring Security + JWT | `9090` |
| **Frontend** | React (Vite) · TailwindCSS · Nginx | `80` |
| **Database** | MongoDB 7.0 | `27017` (internal only) |

**Integrations:** Razorpay · AWS S3 · Google Drive · Gemini AI · Spring Mail · MSG91 OTP

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (Minikube / K3s)                       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     Namespace: bodhganga                            │    │
│  │                                                                     │    │
│  │  Frontend (2 replicas) — React + Nginx — NodePort :30080            │    │
│  │       │  API calls → /api/*                                         │    │
│  │  Backend (3 replicas) — Spring Boot — ClusterIP :9090               │    │
│  │       │  Integrations: Razorpay · AWS S3 · Gemini · Google Drive    │    │
│  │       │  Exposes: /actuator/prometheus                               │    │
│  │  MongoDB (StatefulSet) — mongo:7.0 — Headless :27017                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    Namespace: monitoring                            │    │
│  │                                                                     │    │
│  │  Prometheus ──► Alertmanager ──► Discord / Slack                   │    │
│  │      │                                                              │    │
│  │  Grafana · Node Exporter · kube-state-metrics                      │    │
│  │  Prometheus Operator (reads ServiceMonitor / PrometheusRule CRDs)  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Secrets: JWT · MongoDB URI · AWS · Razorpay · SMTP · Gemini                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow

```
User Browser
    │
    ▼
React Frontend (Nginx :80 / NodePort 30080)
    │  REST calls → /api/*
    ▼
Spring Boot Backend (:9090)
    ├── Spring Security + JWT
    ├── MongoDB (primary store)
    ├── AWS S3 (file storage)
    ├── Google Drive (ingestion)
    ├── Razorpay (payments)
    ├── Gemini AI
    └── /actuator/prometheus  ← metrics endpoint
              │
              │  Prometheus Operator scrapes every 30s (ServiceMonitor CRD)
              ▼
        Prometheus TSDB (30-day retention)
              │
              ├──► Alert Evaluation (PrometheusRule CRD)
              │         │  Routes by severity
              │         ▼
              │    Alertmanager → Discord / Slack
              │
              └──► Grafana Dashboards → http://localhost:3000
```

---

## ✨ Features

| Feature | Description | SRE Concept |
|---|---|---|
| **Cluster Health Monitoring** | Node CPU, memory, disk via Node Exporter | Capacity Planning |
| **Application Performance Monitoring** | HTTP latency p50/p95/p99, error rate, throughput | SLI Measurement |
| **JVM Deep Dive** | Heap, GC pauses, thread count, connection pools | MELT Observability |
| **MongoDB Health** | Connection pool queue monitoring | Database SRE |
| **Security Alerting** | 401 spike detection for JWT / brute-force events | Security Monitoring |
| **Automated Incident Notifications** | Discord / Slack alerts within 1 minute of breach | Incident Management |
| **Zero-downtime Deployments** | Rolling update with PodDisruptionBudget | Change Management |
| **High Availability** | 3 backend replicas with topology spread | Fault Tolerance |
| **Auto-healing** | Liveness + Readiness + Startup probes | Self-healing Systems |
| **SLO-aligned Alerting** | Error rate > 5% and p99 latency > 2s thresholds | Error Budget |
| **Secrets Management** | All credentials in Kubernetes Secrets | Security Hardening |
| **GitOps Ready** | All config is declarative YAML | Infrastructure as Code |

---

## 📁 Project Structure

```
CloudPulse/
│
├── bodhganga/                         ← BodhGanga full-stack application
│   ├── backend/                       ← Spring Boot 3.4.5 API
│   │   ├── src/main/resources/
│   │   │   ├── application.properties ← Updated: Prometheus + Micrometer
│   │   │   ├── application-dev.properties
│   │   │   └── application-prod.properties
│   │   ├── Dockerfile                 ← Upgraded: 3-stage layered build
│   │   └── pom.xml                    ← Updated: micrometer-registry-prometheus
│   ├── frontend/                      ← React (Vite) + Nginx SPA
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   └── docker-compose.yml             ← Local dev workflow (unchanged)
│
├── k8s/                               ← Kubernetes manifests
│   ├── namespace.yaml
│   ├── Secret.yaml                    ← Credentials template (populate before apply)
│   ├── Deployment.yaml                ← Backend + Frontend + MongoDB StatefulSet
│   ├── Service.yaml                   ← 3 services + 2 PodDisruptionBudgets
│   ├── ServiceMonitor.yaml            ← Prometheus auto-scrape on port 9090
│   ├── PrometheusRule.yaml            ← 10 alert rules
│   └── AlertmanagerConfig.yaml        ← Discord / Slack routing
│
├── helm/
│   └── prometheus-values.yaml         ← kube-prometheus-stack overrides
│
├── scripts/
│   ├── setup-cluster.sh               ← Installs Docker + kubectl + Helm + Minikube
│   └── deploy-stack.sh                ← One-shot full stack deployment
│
└── README.md
```

> **Only 3 files were modified in BodhGanga** — `pom.xml`, `application.properties`, and `Dockerfile`. No business logic was touched.

---

## 🔧 Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Docker | 24.x+ | Container runtime |
| Minikube | 1.33+ | Local Kubernetes |
| kubectl | 1.29+ | Cluster management |
| Helm | 3.14+ | Package manager |
| Java | 17 | Backend runtime |
| Maven | 3.9+ | Backend build |
| Node.js | 20+ | Frontend build |

> **Windows users:** Run all Bash scripts inside WSL2 (Ubuntu). Docker Desktop with WSL2 backend is recommended.

---

## 🚀 Deployment Guide

### Step 1 — Bootstrap the Cluster

```bash
git clone https://github.com/codes-by-utkarsh/CloudPulse.git
cd CloudPulse

chmod +x scripts/setup-cluster.sh scripts/deploy-stack.sh

sudo ./scripts/setup-cluster.sh

kubectl get nodes
```

Expected output:
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.30.x
```

---

### Step 2 — Configure Secrets

> ⚠️ Do this before applying any manifests. Never commit a populated Secret to Git.

Open `k8s/Secret.yaml` and replace the placeholder base64 values with your real credentials.

```bash
echo -n 'your-real-value' | base64
```

Minimum required fields:

| Key | How to generate |
|---|---|
| `mongo-root-user` | `echo -n 'admin' \| base64` |
| `mongo-root-pass` | `echo -n 'your-password' \| base64` |
| `mongo-uri` | `echo -n 'mongodb://admin:pass@bodhganga-mongodb:27017/bodhganga?authSource=admin' \| base64` |
| `jwt-secret` | `openssl rand -base64 64 \| tr -d '\n' \| base64` |

---

### Step 3 — Build Docker Images

```bash
eval $(minikube docker-env)

docker build -t bodhganga-backend:1.0.0 bodhganga/backend/

docker build \
  --build-arg VITE_API_BASE_URL="http://$(minikube ip):9090/api" \
  -t bodhganga-frontend:1.0.0 \
  bodhganga/frontend/

docker images | grep bodhganga
```

---

### Step 4 — Deploy BodhGanga Stack

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/Secret.yaml
kubectl apply -f k8s/Deployment.yaml
kubectl apply -f k8s/Service.yaml

kubectl get pods -n bodhganga -w
```

Expected — all pods Running:
```
NAME                                  READY   STATUS    RESTARTS   AGE
bodhganga-backend-xxx-yyy             1/1     Running   0          60s
bodhganga-backend-xxx-zzz             1/1     Running   0          60s
bodhganga-backend-xxx-aaa             1/1     Running   0          60s
bodhganga-frontend-xxx-bbb            1/1     Running   0          30s
bodhganga-frontend-xxx-ccc            1/1     Running   0          30s
bodhganga-mongodb-0                   1/1     Running   0          90s
```

Smoke test:
```bash
kubectl port-forward svc/bodhganga-backend-svc 9090:9090 -n bodhganga &
curl http://localhost:9090/actuator/health
curl http://localhost:9090/actuator/prometheus | head -20

minikube service bodhganga-frontend-svc -n bodhganga
```

---

### Step 5 — Deploy Observability Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install cloudpulse-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/prometheus-values.yaml \
  --wait \
  --timeout 10m

kubectl get pods -n monitoring

kubectl apply -f k8s/ServiceMonitor.yaml
```

Verify BodhGanga appears as a scrape target:
```bash
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring &
```
Open **http://localhost:9091/targets** → look for `bodhganga-backend-svc`.

---

### Step 6 — Configure Alerts

```bash
kubectl apply -f k8s/PrometheusRule.yaml
```

Get your Discord webhook URL:
> Discord Server → Channel Settings → Integrations → Webhooks → New Webhook → Copy URL

Edit `k8s/AlertmanagerConfig.yaml` and replace `REPLACE_WITH_YOUR_CRITICAL_WEBHOOK_URL` with your URL, then:

```bash
kubectl apply -f k8s/AlertmanagerConfig.yaml
```

Test it:
```bash
kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring &

curl -X POST http://localhost:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"warning","service":"bodhganga"},
    "annotations": {"summary":"Test alert from CloudPulse"}
  }]'
```

---

### Step 7 — Access Grafana

```bash
kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring
```

Open **http://localhost:3000**

| | |
|---|---|
| Username | `admin` |
| Password | `CloudPulse@2024!` |

Import dashboards: **Dashboards → Import → Enter ID → Select Prometheus → Import**

---

## 🔌 Port Reference

| Service | How to access |
|---|---|
| BodhGanga Frontend | `http://$(minikube ip):30080` |
| BodhGanga Backend API | `kubectl port-forward svc/bodhganga-backend-svc 9090:9090 -n bodhganga` |
| Raw Prometheus metrics | `http://localhost:9090/actuator/prometheus` (after above) |
| Grafana | `kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring` → `http://localhost:3000` |
| Prometheus UI | `kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring` → `http://localhost:9091` |
| Alertmanager | `kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring` → `http://localhost:9093` |

---

## 📊 Grafana Dashboards

| ID | Dashboard | Best For |
|---|---|---|
| **`4701`** ⭐ | JVM (Micrometer) | BodhGanga heap, GC, HTTP — start here |
| **`12900`** | Spring Boot Statistics | Error rate, latency percentiles |
| **`11378`** | Spring Boot System Monitor | CPU, memory, disk |
| **`7249`** | Kubernetes Cluster Overview | Node health, pod counts |
| **`1860`** | Node Exporter Full | Hardware metrics per node |
| **`9578`** | Alertmanager | Alert routing status |

---

## 🚨 Alert Rules Reference

| Alert | Condition | Severity | Duration |
|---|---|---|---|
| `BodhGangaTargetDown` | Pod unreachable | 🔴 critical | 1 min |
| `BodhGangaReplicasMissing` | Ready replicas < 3 | ⚠️ warning | 2 min |
| `BodhGangaHighErrorRate` | HTTP 5xx > 5% | 🔴 critical | 5 min |
| `BodhGangaHighLatency` | p99 > 2s | ⚠️ warning | 5 min |
| `BodhGangaAuthFailureSpike` | 401 rate > 10/s | ⚠️ warning | 3 min |
| `HighNodeCpuUsage` | CPU > 80% | ⚠️ warning | 5 min |
| `HighNodeMemoryUsage` | Memory > 85% | ⚠️ warning | 5 min |
| `LowDiskSpace` | Disk free < 15% | ⚠️ warning | 10 min |
| `BodhGangaJvmHeapHigh` | JVM heap > 85% | ⚠️ warning | 5 min |
| `BodhGangaMongoPoolExhausted` | MongoDB wait queue > 5 | ⚠️ warning | 3 min |

---

## 🛡️ SRE Concepts Applied

### Four Golden Signals

| Signal | Metric | Alert |
|---|---|---|
| **Latency** | `http_server_requests_seconds` p99 | > 2s |
| **Traffic** | `rate(http_server_requests_seconds_count[5m])` | Dashboard |
| **Errors** | 5xx / total ratio | > 5% |
| **Saturation** | JVM heap / CPU / MongoDB pool | Multiple alerts |

### Zero-Downtime Deployment

```
New image built → kubectl set image
    │
    ▼  Rolling Update (maxUnavailable: 1, maxSurge: 1)
New Pod starts → Startup Probe (120s grace)
    │           → Readiness Probe (MongoDB + Spring healthy?)
    ▼
Old Pod terminates → 30s drain window
    ▼
Zero downtime ✓
```

### SLO Tracking (PromQL)

```promql
sum(rate(http_server_requests_seconds_bucket{le="0.5",namespace="bodhganga"}[5m]))
/
sum(rate(http_server_requests_seconds_count{namespace="bodhganga"}[5m]))
```

---

## 🔍 Troubleshooting

**Backend pods in CrashLoopBackOff:**
```bash
kubectl logs -n bodhganga -l app.kubernetes.io/name=bodhganga-backend --tail=100
kubectl describe pod -n bodhganga -l app.kubernetes.io/name=bodhganga-backend
```

**`/actuator/prometheus` returns 404:**
```bash
kubectl exec -it deployment/bodhganga-backend -n bodhganga -- \
  wget -qO- http://localhost:9090/actuator
```
If `prometheus` is not listed, rebuild the image after updating `pom.xml`.

**ServiceMonitor not picked up:**
```bash
kubectl get servicemonitor -n bodhganga -o yaml | grep "release:"
```
Must match: `release: cloudpulse-prometheus`

**Wrong Secret values:**
```bash
kubectl delete secret bodhganga-secrets -n bodhganga
kubectl apply -f k8s/Secret.yaml
kubectl rollout restart deployment/bodhganga-backend -n bodhganga
```

**Minikube out of resources:**
```bash
minikube stop && minikube delete
minikube start --cpus=6 --memory=8192 --disk-size=40g --addons=ingress,metrics-server
```

---

<div align="center">

Built with ❤️ — **CloudPulse** observability platform for **BodhGanga**

</div>
