# 🏃‍♂️ Race Tracker App — Kubernetes & Microservices Demo

## 🎯 Overview
A demo platform that simulates real-time runner tracking for races (5K, 10K, Half-Marathon, Ultramarathon).  
Built to demonstrate **microservices, Kubernetes (with Strimzi Kafka), Redis caching, and WebSocket streaming** across a **polyglot architecture**.

### Tech Stack

| Layer | Technology |
|-------|-------------|
| **Frontend** | Next.js (Node.js) |
| **Microservices** | Java (Spring Boot), Python (FastAPI), Go |
| **Messaging** | Apache Kafka (via Strimzi Operator) |
| **Cache / Pub-Sub** | Redis |
| **Database** | MongoDB |
| **Platform** | Kubernetes (Envoy Gateway for microservices) |
| **CI/CD** | GitHub Actions / Azure Pipelines |
| **Simulation** | Python or Go synthetic data generator |
| **Real-Time UI** | WebSockets (Next.js backend + Redis Pub/Sub) |

---

## 🧩 Core Features

### 1. Race Management (Spring Boot)
- Manage race definitions, distances, and checkpoints  
- Store configuration in MongoDB  
- REST API for frontend  

### 2. Runner Registration (FastAPI)
- Register runners for races  
- Assign bib numbers and starting waves  
- Provide API for simulation to reference registered runners  

### 3. Live Tracking (Go)
- Consumes runner position events from Kafka (`runner-positions`)  
- Computes pace, ETA, and splits  
- Publishes results to Kafka (`race-stats`)  
- Pushes updates to Redis for real-time cache and WebSocket broadcast  

### 4. Kafka Event Bus (Strimzi Operator)
- Topics:
  - `runner-positions` → raw telemetry data  
  - `race-stats` → aggregated runner stats  
  - `alerts` → missed checkpoints, slowdown alerts, etc.  
- Demonstrates event-driven architecture on Kubernetes  

### 5. Simulation Service (Python)
- Generates synthetic telemetry for all runners  
- Pushes to `runner-positions` Kafka topic  
- Configurable parameters (race type, pace variability, delay injection, etc.)  
- Can simulate hundreds or thousands of runners for load testing  

### 6. Redis Integration
- **Cache Layer:**  
  - Cache frequently accessed runner data and race states  
  - Reduce MongoDB reads for leaderboard and stats  
- **Pub/Sub Bridge:**  
  - Live tracking service publishes updates to Redis channels  
  - WebSocket gateway subscribes and pushes updates to connected clients  
- Enables scalable, low-latency real-time updates independent of Kafka  

### 7. Real-Time WebSocket Gateway (Node.js / Next.js API Route)
- Maintains persistent WebSocket connections to clients  
- Subscribes to Redis Pub/Sub channels (e.g., `race:updates`)  
- Emits live runner updates and leaderboard changes instantly to the UI  
- Decoupled from main frontend rendering for scalability  

### 8. Analytics Service (Spring Boot or FastAPI)
- Consumes `race-stats` topic  
- Provides leaderboard, checkpoint stats, and average paces via REST API  
- Exposes Prometheus metrics  

### 9. Frontend Dashboard (Next.js)
- **Live Map View:** Display runner positions via Mapbox or Leaflet  
- **Leaderboard:** Updated in real-time via WebSocket  
- **Race Controls:** Create/start/stop races, trigger simulations  
- **Observability View:** Optional Kafka & Redis topic visualization  

---

## ⚙️ Implementation Plan

### Phase 1 — Foundations
- [ ] Set up Kubernetes cluster (k3s, AKS, or GKE)  
- [ ] Deploy Strimzi Kafka Operator  
- [ ] Deploy MongoDB (StatefulSet)  
- [ ] Deploy Redis (Helm or Operator)  
- [ ] Scaffold Next.js frontend  
- [ ] Configure CI/CD pipeline (GitHub Actions / Azure Pipelines)

### Phase 2 — Core Microservices
- [x] **Race Management (Spring Boot)** — CRUD + MongoDB ✅ COMPLETED  
- [x] **Runner Registration (FastAPI)** — CRUD + MongoDB ✅ COMPLETED  
- [x] Define Helm charts for both services ✅ COMPLETED  
- [x] Create Kafka topics via Strimzi CRDs ✅ COMPLETED  

### Phase 3 — Streaming and Simulation
- [x] **Simulation Service (Python)** — generate `runner-positions` Kafka events ✅ COMPLETED  
- [x] **Live Tracking (Go)** — consume Kafka, publish to Redis + `race-stats` ✅ COMPLETED  
- [x] Verify Kafka message flow ✅ COMPLETED  
- [x] Test Redis pub/sub for real-time broadcast ✅ COMPLETED  

### Phase 4 — WebSocket and Frontend Integration
- [x] **WebSocket Gateway (Custom Node.js Server)** — connect Redis Pub/Sub to UI ✅ COMPLETED  
- [x] Integrate frontend WebSocket client to update runner map + leaderboard ✅ COMPLETED  
- [x] Add REST API for cached data (leaderboard, stats) ✅ COMPLETED  
- [ ] Add fallback to REST polling if WebSocket unavailable  
- [ ] Add map visualization + controls for race simulation  

### Phase 5 — Observability & Scaling
- [ ] Add Prometheus + Grafana dashboards  
- [ ] Add Jaeger or OpenTelemetry tracing  
- [ ] Simulate large race loads (e.g., 1,000+ runners)  
- [ ] Demo Redis caching improvements and scaling under load  

### Phase 6 — Polishing the Demo
- [ ] Finalize Helm charts for all microservices  
- [ ] CI/CD pipelines for automated deploys  
- [ ] Add Chaos testing (kill pods mid-stream, observe recovery)  
- [ ] Document architecture and Kubernetes manifests  
- [ ] Optional: Add replay mode for completed races  

---

## 🧱 Updated Kubernetes Components

| Component | Type | Purpose |
|------------|------|----------|
| `strimzi-kafka-cluster` | Operator-managed | Kafka event streaming backbone |
| `mongodb` | StatefulSet | Race + runner data |
| `redis` | StatefulSet | Caching + Pub/Sub for WebSocket updates |
| `race-management` | Deployment | Spring Boot CRUD service ✅ |
| `runner-registration` | Deployment | FastAPI runner service ✅ |
| `live-tracking` | Deployment | Go Kafka consumer + Redis publisher ✅ |
| `simulation` | Deployment | Python telemetry generator ✅ |
| `analytics-service` | Deployment | Aggregation + leaderboard |
| `websocket-gateway` | Deployment | WebSocket <-> Redis bridge |
| `frontend` | Deployment | Next.js web dashboard |
| `gateway` | Ingress | Routes frontend + APIs externally |

---

## 🧠 Demonstration Scenarios

1. **Live Race Visualization:**  
   WebSocket-driven updates from Redis to frontend in real time.  
2. **Load Test with 1,000+ Runners:**  
   Kafka, Redis, and Kubernetes autoscaling under stress.  
3. **Cache Efficiency:**  
   Redis drastically reduces leaderboard query latency.  
4. **Fault Tolerance:**  
   Kill pods or Redis nodes, show graceful recovery.  
5. **Polyglot Microservices in Harmony:**  
   Spring Boot, FastAPI, and Go all interoperating via Kafka.  
6. **Tracing a Single Runner’s Journey:**  
   View data through Kafka → Redis → WebSocket → Frontend.  

---

