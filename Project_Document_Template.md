# Title of the Project
**Microservices based Logistics & Inventory Management System (IMS)**

## 1. Architecture

| Microservice Name | Internal Port | Service Type | Exposed URL (via Ingress / Fanout DNS) | API Names / Routes | Allowed Roles | MongoDB Atlas Collection |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **API Gateway** | 4000 | `NodePort` (30080) / Ingress | `http://ims.com/` | `GET /`<br>`GET /health`<br>`GET /logs` | Public / All | N/A (Shared PV `/var/log/app`) |
| **Registration** | 5001 | `ClusterIP` (Internal only) | `http://ims.com/register` | `POST /register` | Public | `members` |
| **Login** | 5002 | `ClusterIP` (Internal only) | `http://ims.com/login`<br>`http://ims.com/logout` | `POST /login`<br>`POST /logout` | Public<br>Authenticated | `members` |
| **Catalog** | 5003 | `ClusterIP` (Internal only) | `http://ims.com/products` | `POST /products`<br>`GET /products/:id`<br>`PUT /products/:id` | `Manager`<br>`Manager`, `Worker`<br>`Manager` | `Catalog` |
| **Inventory** | 5004 | `ClusterIP` (Internal only) | `http://ims.com/inventory/:sku` | `GET /inventory/:sku`<br>`PUT /inventory/:sku/adjust` | `Manager`, `Worker`<br>`Worker` | `Inventory` |
| **Order** | 5005 | `ClusterIP` (Internal only) | `http://ims.com/orders` | `POST /orders`<br>`GET /orders/pending`<br>`PUT /orders/:id/status` | `Manager`<br>`Worker`<br>`Worker` | `Fulfillment` |
| **Inbound** | 5006 | `ClusterIP` (Internal only) | `http://ims.com/shipments` | `POST /shipments`<br>`PUT /shipments/:id/verify` | `Manager`<br>`Worker` | `shipment_collections` |
| **User Profile** | 5007 | `ClusterIP` (Internal only) | `http://ims.com/viewprofile`<br>`http://ims.com/updateprofile` | `GET /viewprofile`<br>`PUT /updateprofile` | Authenticated | `members` |

*Note: All client traffic enters via **NGINX Fanout Ingress** on Host `ims.com` (Port 80) and routes to the **API Gateway** (Port 4000). Direct external access to individual backend microservices is strictly blocked by `ClusterIP` network isolation.*

---

## 2. Kubernetes Cluster Status Verification

```bash
kubectl get pods,svc,ingress,pv,pvc -o wide
```

### Deployed Pods (Replicas: 2 & Multi-Container Gateway):
- `apigateway-deployment` (2/2 Running - multi-container: `api-gateway-container` + `log-sidecar-container`)
- `registration-deployment` (2/2 Running)
- `login-deployment` (2/2 Running)
- `catalog-deployment` (2/2 Running)
- `inventory-deployment` (2/2 Running)
- `order-deployment` (2/2 Running)
- `inbound-deployment` (2/2 Running)
- `userprofile-deployment` (2/2 Running)

### Ingress Configuration:
- `ims-fanout-ingress` (Hosts: `ims.com`, `ims` on `192.168.49.2:80`)

### Kubernetes Volumes:
- `app-logs-pv` (1Gi, ReadWriteMany, Bound)
- `app-logs-pvc` (1Gi, Bound) mounted at `/var/log/app` across both containers

---

## 3. Screenshots Checklist

### A. Collection Name and Schema Code
*(Insert screenshots of your code showing the Mongoose Schemas and MongoDB Atlas dashboard showing the collections)*
1. **Schema Code**:
   - `person_schema.js` (`members` collection)
   - `catalog_schema.js` (`Catalog` collection)
   - `inventory_schema.js` (`Inventory` collection)
   - `order_schema.js` (`Fulfillment` collection)
   - `inbound_schema.js` (`shipment_collections` collection)
2. **MongoDB Atlas Dashboard**:
   - Screenshot showing database `cloudmongo1` with all collections: `members`, `Catalog`, `Inventory`, `Fulfillment`, `shipment_collections`.

### B. All API Calls using Postman (`http://ims.com`) + MongoDB Database
*(Import `IMS_Microservices.postman_collection.json` into Postman and capture responses)*
1. **API Gateway & Logging**:
   - `GET http://ims.com/` (Returns domain `ims.com`, status `UP`)
   - `GET http://ims.com/health`
   - `GET http://ims.com/logs` (Returns shared volume access logs)
2. **User Registration & Login**:
   - `POST http://ims.com/register` (Manager)
   - `POST http://ims.com/register` (Worker)
   - `POST http://ims.com/login` (Manager - returns JWT Token)
   - `POST http://ims.com/login` (Worker - returns JWT Token)
3. **Catalog & Inventory**:
   - `POST http://ims.com/products` (Manager creates product)
   - `PUT http://ims.com/inventory/:sku/adjust` (Worker sets initial stock)
   - `GET http://ims.com/products/:id` (Returns product aggregated with live stock from Inventory)
   - `PUT http://ims.com/products/:id` (Manager updates product price/description)
4. **Order Fulfillment**:
   - `POST http://ims.com/orders` (Manager places order with status `pending`)
   - `GET http://ims.com/orders/pending` (Worker lists pending orders)
   - `PUT http://ims.com/orders/:id/status` (Worker updates status to `picked` then `packed`)
5. **Inbound Receiving**:
   - `POST http://ims.com/shipments` (Manager logs incoming shipment)
   - `PUT http://ims.com/shipments/:id/verify` (Worker verifies received items)
6. **User Profile**:
   - `GET http://ims.com/viewprofile` (Displays authenticated user details)
   - `PUT http://ims.com/updateprofile` (Updates user name and contact info)
7. **MongoDB Atlas Data**:
   - Screenshots of documents in MongoDB Atlas collections verifying inserted/updated records.

### C. Kubernetes Fanout DNS & Ingress Configuration
1. **Ingress Manifest**: Screenshot of [k8s/05-fanout-ingress.yaml](file:///home/starchy_plastic/Code/NodeJS/Final_FR/k8s/05-fanout-ingress.yaml) showing host `ims.com`.
2. **Terminal Output**:
   - `kubectl get ingress` showing `ims-fanout-ingress` with host `ims.com` and address `192.168.49.2`.
   - `curl -H 'Host: ims.com' http://192.168.49.2/` returning `200 OK`.
   - `curl -H 'Host: aupp.com' http://192.168.49.2/` returning `404 Not Found` (confirming `aupp.com` deleted).

### D. Multi-Container Shared Kubernetes Volume Demonstration
1. **Multi-Container Pod Manifest**: Screenshot of [k8s/04-apigateway-deployment.yaml](file:///home/starchy_plastic/Code/NodeJS/Final_FR/k8s/04-apigateway-deployment.yaml) showing `api-gateway-container` (writer) and `log-sidecar-container` (reader) mounting `app-logs-pvc` to `/var/log/app`.
2. **Sidecar Logs Terminal Output**:
   - `kubectl logs -f <apigateway-pod-name> -c log-sidecar-container` showing real-time streamed logs from `/var/log/app/gateway.log`.

### E. Testing Authentication & Authorization (Negative Scenarios)
1. **Wrong Password or Non-Existent User**:
   - `POST http://ims.com/login` with bad password returning `400 Bad Request`.
2. **Missing or Invalid JWT Token**:
   - Request to protected route without token returning `401 Unauthorized` (`"Please send token"`).
   - Request with invalid/tampered token returning `403 Forbidden` (`"Invalid Token"`).
3. **Role-Based Access Control (RBAC) Violation**:
   - Worker token calling Manager-only route (`POST http://ims.com/products` or `POST http://ims.com/orders`) returning `403 Forbidden` (`"Access Denied: You do not have permission"`).
   - Manager token calling Worker-only route (`PUT http://ims.com/inventory/:sku/adjust` or `GET http://ims.com/orders/pending`) returning `403 Forbidden`.

---

## 4. Source Code & Manifests
- **Repository Path**: `/home/starchy_plastic/Code/NodeJS/Final_FR`
- **Kubernetes Manifests**: [k8s/](file:///home/starchy_plastic/Code/NodeJS/Final_FR/k8s/) and [node_minikube_deploy/](file:///home/starchy_plastic/Code/NodeJS/Final_FR/node_minikube_deploy/)
- **Postman Collection**: [IMS_Microservices.postman_collection.json](file:///home/starchy_plastic/Code/NodeJS/Final_FR/IMS_Microservices.postman_collection.json)
- **GitHub Link**: *(Paste your repository link here)*
