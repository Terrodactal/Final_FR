# Microservices-based Logistics & Inventory Management System

A cloud-native, microservices-based logistics and inventory management system deployed on **Kubernetes (Minikube)** using pure **YAML configuration files**, integrated with **MongoDB Atlas (Cloud Database)**, path-based **Fanout DNS (ims.com / ims)** via NGINX Ingress, and **Multi-Container Pods with Shared Kubernetes Volumes** for access logging.

---

## Architecture & System Overview

```
                      Client / Postman (http://ims.com)
                                      │
                                      ▼
                      ┌──────────────────────────────┐
                      │    NGINX Ingress (ims.com)   │  <-- Fanout DNS Routing (IMS)
                      └──────────────┬───────────────┘
                                     │ (Port 4000)
                                     ▼
                      ┌──────────────────────────────┐
                      │    API Gateway Service       │  <-- Single Point of Entry
                      │   (NodePort / ClusterIP)     │      JWT Auth & RBAC
                      └──────────────┬───────────────┘
                                     │
           ┌──────────┬──────────────┼──────────────┬─────────────┬───────────┐
           │          │              │              │             │           │
           ▼          ▼              ▼              ▼             ▼           ▼
     ┌──────────┐┌──────────┐  ┌───────────┐  ┌───────────┐ ┌───────────┐┌───────────┐
     │Register  ││  Login   │  │  Catalog  │  │ Inventory │ │   Order   ││  Inbound  │
     │Service   ││ Service  │  │  Service  │  │  Service  │ │  Service  ││  Service  │
     │Port 5001 ││Port 5002 │  │ Port 5003 │  │ Port 5004 │ │ Port 5005 ││ Port 5006 │
     └────┬─────┘└────┬─────┘  └─────┬─────┘  └─────┬─────┘ └─────┬─────┘└─────┬─────┘
          │           │              │              │             │            │
          │           │              └──────┬───────┘             │            │
          │           │                     ▼ (Inter-service)     │            │
          │           │              (Stock Aggregation)          │            │
          │           │                                           │            │
          └───────────┴─────────────────────┬─────────────────────┴────────────┘
                                            ▼
                              ┌───────────────────────────┐
                              │  MongoDB Atlas (Cloud DB) │
                              │    (No Local DB Container)│
                              └───────────────────────────┘
```

### Microservices Specification

| Microservice | Internal Port | Service Type | Routing via Gateway | Roles Allowed | MongoDB Collection |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **API Gateway** | 4000 | `NodePort` (30080) / Ingress | `/`, `/logs`, `/health` | Public / All | N/A (Shared Volume) |
| **Registration** | 5001 | `ClusterIP` (Internal only) | `POST /register` | Public | `members` |
| **Login** | 5002 | `ClusterIP` (Internal only) | `POST /login`, `POST /logout`| Public | `members` |
| **Catalog** | 5003 | `ClusterIP` (Internal only) | `POST /products`<br>`GET /products/:id`<br>`PUT /products/:id` | `Manager`<br>`Manager`, `Worker`<br>`Manager` | `Catalog` |
| **Inventory** | 5004 | `ClusterIP` (Internal only) | `GET /inventory/:sku`<br>`PUT /inventory/:sku/adjust` | `Manager`, `Worker`<br>`Worker` | `Inventory` |
| **Order** | 5005 | `ClusterIP` (Internal only) | `POST /orders`<br>`GET /orders/pending`<br>`PUT /orders/:id/status` | `Manager`<br>`Worker`<br>`Worker` | `Fulfillment` |
| **Inbound** | 5006 | `ClusterIP` (Internal only) | `POST /shipments`<br>`PUT /shipments/:id/verify` | `Manager`<br>`Worker` | `shipment_collections` |
| **User Profile** | 5007 | `ClusterIP` (Internal only) | `GET /viewprofile`<br>`PUT /updateprofile` | Any Valid Token | `members` |

---

## Compliance with Project Guidelines

### 1. Kubernetes Deployment
All services are containerized and deployed strictly using declarative **YAML configuration files** located in [k8s/](file:///home/starchy_plastic/Code/NodeJS/Final_FR/k8s/) and [node_minikube_deploy/](file:///home/starchy_plastic/Code/NodeJS/Final_FR/node_minikube_deploy/).
- `01-secrets-config.yaml`: Centralized Secret (`logistics-secrets`) and ConfigMap (`logistics-config`).
- `02-volume.yaml`: PersistentVolume (`app-logs-pv`) and PersistentVolumeClaim (`app-logs-pvc`).
- `03-backend-deployments.yaml`: Deployments and ClusterIP Services for all 7 backend microservices.
- `04-apigateway-deployment.yaml`: Multi-container API Gateway deployment with log-sidecar and shared volume mount.
- `05-fanout-ingress.yaml`: NGINX Ingress rules routing `ims.com` to the API Gateway.
- `all-in-one.yaml`: Unified single-file manifest.

### 2. Pod Configuration
- Every microservice runs with **multiple Pod replicas** (`replicas: 2`) across the cluster.
- The **API Gateway Pod** runs a **multi-container configuration** (`api-gateway-container` + `log-sidecar-container`).

### 3. API Gateway Routing
- **Single Point of Entry**: All external client requests are routed through the API Gateway on port 4000 (or Ingress port 80).
- **Strict Isolation**: All backend microservices (Registration, Login, Catalog, Inventory, Order, Inbound, User Profile) use **`ClusterIP`** services. They have no external NodePort or LoadBalancer and cannot be accessed directly by clients.
- **Security & Authorization**: The API Gateway enforces JWT token validation (`authToken`) and role-based access control (`authRole(['Manager', 'Worker'])`).

### 4. Database Connectivity (Cloud Database)
- **Zero Local Docker Database**: No containerized database is used.
- All persistent data is hosted on **MongoDB Atlas** (Cloud Database Cluster: `cluster0.5lt6slh.mongodb.net/cloudmongo1`).
- Credentials and connection strings are securely injected via Kubernetes Secrets (`logistics-secrets`).

### 5. Fanout DNS Configuration (IMS / ims.com)
- Path-based **Fanout DNS** is implemented with Kubernetes NGINX Ingress (`ims-fanout-ingress`) configured for domain **`ims.com`** (and alias **`ims`**).
- Incoming paths (`/register`, `/login`, `/products`, `/inventory`, `/orders`, `/shipments`, `/viewprofile`, `/updateprofile`, `/logs`, `/health`) fan out to the API Gateway.
- DNS resolution can be tested by adding `$(minikube ip) ims.com ims` to `/etc/hosts` or passing `-H "Host: ims.com"` with curl.

### 6. Kubernetes Volumes & Multi-Container Demonstration
- A Kubernetes **PersistentVolume** (`app-logs-pv`) and **PersistentVolumeClaim** (`app-logs-pvc`) provide shared storage at `/var/log/app`.
- **Demonstration across multiple containers**:
  1. Container 1 (`api-gateway-container`) writes structured access logs to `/var/log/app/gateway.log`.
  2. Container 2 (`log-sidecar-container`, running `busybox`) mounts the same volume and continuously tails `/var/log/app/gateway.log`.
  3. Stored logs can also be accessed via `GET /logs` through the API Gateway or inspected with `kubectl logs <pod> -c log-sidecar-container`.

### 7. Local Deployment on Minikube
The entire application is deployed and tested locally on Minikube with the `ingress` addon enabled.

---

## Deployment Instructions

### Prerequisites
- Docker
- Minikube
- Kubectl

### Step 1: Start Minikube & Enable Ingress
```bash
minikube start
minikube addons enable ingress
```

### Step 2: Build & Load Docker Images into Minikube
Run from the project root:
```bash
# Build images
docker build -t logistics-api-gateway:v1.0 APIGateway_microservice
docker build -t logistics-registration:v1.0 Registration_microservice
docker build -t logistics-login:v1.0 Login_microservice
docker build -t logistics-catalog:v1.0 Catalog_microservice
docker build -t logistics-inventory:v1.0 Inventory_microservice
docker build -t logistics-order:v1.0 Order_microservice
docker build -t logistics-inbound:v1.0 Inbound_microservice
docker build -t logistics-userprofile:v1.0 UserProfile_microservice

# Load images into Minikube
minikube image load busybox:latest
minikube image load logistics-api-gateway:v1.0
minikube image load logistics-registration:v1.0
minikube image load logistics-login:v1.0
minikube image load logistics-catalog:v1.0
minikube image load logistics-inventory:v1.0
minikube image load logistics-order:v1.0
minikube image load logistics-inbound:v1.0
minikube image load logistics-userprofile:v1.0
```

### Step 3: Apply Kubernetes Manifests
```bash
kubectl apply -f k8s/01-secrets-config.yaml
kubectl apply -f k8s/02-volume.yaml
kubectl apply -f k8s/03-backend-deployments.yaml
kubectl apply -f k8s/04-apigateway-deployment.yaml
kubectl apply -f k8s/05-fanout-ingress.yaml

# Or apply all at once:
# kubectl apply -f k8s/all-in-one.yaml
```

### Step 4: Verify Resources
```bash
kubectl get pods,svc,ingress,pvc
```
All Pods should reach `Running` state and the PVC should show `Bound`.

---

## Testing & Verification

### Configure Local DNS (Optional)
Map Minikube IP to `ims.com`:
```bash
echo "$(minikube ip) ims.com" | sudo tee -a /etc/hosts
```
*(Alternatively, supply `-H "Host: ims.com"` to curl commands).*

### 1. Register Users
**Manager Account:**
```bash
curl -X POST http://ims.com/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Manager Alice","email":"alice@ims.com","password":"secretpassword","mobile":12345678,"role":"Manager"}'
```

**Worker Account:**
```bash
curl -X POST http://ims.com/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Worker Bob","email":"bob@ims.com","password":"secretpassword","mobile":87654321,"role":"Worker"}'
```

### 2. Login & Obtain JWT Token
```bash
# Manager Login
curl -X POST http://ims.com/login \
  -H "Content-Type: application/json" \
  -d '{"emailid":"alice@ims.com","password":"secretpassword","role":"Manager"}'

# Worker Login
curl -X POST http://ims.com/login \
  -H "Content-Type: application/json" \
  -d '{"emailid":"bob@ims.com","password":"secretpassword","role":"Worker"}'
```
*Export tokens for subsequent calls:*
```bash
export MGR_TOKEN="<MANAGER_JWT_TOKEN>"
export WRK_TOKEN="<WORKER_JWT_TOKEN>"
```

### 3. Product Catalog & Inventory Aggregation
**Create Product (Manager required):**
```bash
curl -X POST http://ims.com/products \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"sku":"SKU-500","name":"Logitech MX Master 3S","description":"Performance wireless mouse","price":99.99,"category":"Hardware"}'
```

**Adjust Inventory Stock (Worker required):**
```bash
curl -X PUT http://ims.com/inventory/SKU-500/adjust \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quantity":120}'
```

**Get Product with Live Stock Count (Catalog aggregates from Inventory):**
```bash
curl -X GET http://ims.com/products/<PRODUCT_ID> \
  -H "Authorization: Bearer $WRK_TOKEN"
```

### 4. Order Fulfillment
**Create Order (Manager):**
```bash
curl -X POST http://ims.com/orders \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customerName":"Alice Walker","itemSku":"SKU-500","quantity":5}'
```

**View Pending Orders (Worker):**
```bash
curl -X GET http://ims.com/orders/pending \
  -H "Authorization: Bearer $WRK_TOKEN"
```

**Update Order Status (Worker):**
```bash
curl -X PUT http://ims.com/orders/<ORDER_ID>/status \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"packed"}'
```

### 5. Inbound Receiving
**Create Shipment (Manager):**
```bash
curl -X POST http://ims.com/shipments \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"supplierName":"TechDistributor Inc","itemSku":"SKU-500","quantity":300}'
```

**Verify Shipment (Worker):**
```bash
curl -X PUT http://ims.com/shipments/<SHIPMENT_ID>/verify \
  -H "Authorization: Bearer $WRK_TOKEN"
```

### 6. User Profile Management
**View Profile:**
```bash
curl -X GET http://ims.com/viewprofile \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"emailid":"alice@ims.com"}'
```

**Update Profile:**
```bash
curl -X PUT http://ims.com/updateprofile \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"emailid":"alice@ims.com","name":"Alice Senior Manager","mobile":99998888}'
```

---

## Negative Testing Scenarios (Security & RBAC)

1. **Wrong Password (HTTP 400):**
   ```bash
   curl -i -X POST http://ims.com/login \
     -H "Content-Type: application/json" \
     -d '{"emailid":"alice@ims.com","password":"badpassword","role":"Manager"}'
   ```
2. **Missing Token on Protected Route (HTTP 401):**
   ```bash
   curl -i -X POST http://ims.com/products \
     -H "Content-Type: application/json" \
     -d '{"sku":"SKU-TEST","name":"Test"}'
   ```
3. **Invalid Token (HTTP 403):**
   ```bash
   curl -i -X POST http://ims.com/products \
     -H "Authorization: Bearer invalid.token.value" \
     -H "Content-Type: application/json" \
     -d '{"sku":"SKU-TEST","name":"Test"}'
   ```
4. **Role-Based Unauthorized - Worker accessing Manager Route (HTTP 403):**
   ```bash
   curl -i -X POST http://ims.com/products \
     -H "Authorization: Bearer $WRK_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"sku":"SKU-TEST","name":"Test"}'
   ```

---

## Demonstrating Multi-Container Shared Volume Access

1. Inspect the log file created by `api-gateway-container` from within the `log-sidecar-container`:
   ```bash
   kubectl exec deployment/apigateway-deployment -c log-sidecar-container -- cat /var/log/app/gateway.log
   ```
2. View the live sidecar stream:
   ```bash
   kubectl logs -f deployment/apigateway-deployment -c log-sidecar-container
   ```
3. View stored volume logs via the Gateway endpoint:
   ```bash
   curl http://ims.com/logs
   ```
