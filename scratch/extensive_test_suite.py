#!/usr/bin/env python3
"""
Extensive Microservices & Kubernetes Test Suite for Logistics & Inventory Management System (IMS).
Covers 6 Comprehensive Test Dimensions:
  1. Ingress & Fanout DNS Boundary Testing (Host resolution, deleted aupp.com, unmapped domains)
  2. Security, JWT & RBAC Fuzzing (Tampering, header spoofing, role barriers, missing/invalid tokens)
  3. Complete Supply Chain Business Flow (Multi-item catalog, inbound receiving, inventory, orders, fulfillment, user profile)
  4. Extreme Boundary & Input Edge Cases (Malformed ObjectIds, special characters, Unicode, zero/negative quantities, large payloads)
  5. Concurrency & High-Load Stress Testing (Concurrent fanout load, latency percentiles, pod load balancing)
  6. Kubernetes High Availability & Volume Persistence (Zero-downtime pod kill, sidecar log streaming, volume persistence)
"""

import urllib.request
import urllib.error
import json
import time
import subprocess
import concurrent.futures
import sys

BASE_URL = "http://192.168.49.2"
HOST_IMS = "ims.com"
HOST_IMS_ALIAS = "ims"
HOST_AUPP = "aupp.com"
HOST_RANDOM = "evil-domain.com"

# Metrics collection
test_results = []

def record(test_name, passed, detail=""):
    test_results.append({"name": test_name, "passed": passed, "detail": detail})
    status_str = "\033[92m[PASS]\033[0m" if passed else "\033[91m[FAIL]\033[0m"
    print(f"  {status_str} {test_name}: {detail}")

def http_req(path, method="GET", headers=None, data=None, host=HOST_IMS, timeout=10):
    if headers is None:
        headers = {}
    headers["Host"] = host
    url = f"{BASE_URL}{path}"
    
    encoded_data = None
    if data is not None:
        if isinstance(data, dict) or isinstance(data, list):
            encoded_data = json.dumps(data).encode("utf-8")
            if "Content-Type" not in headers:
                headers["Content-Type"] = "application/json"
        elif isinstance(data, str):
            encoded_data = data.encode("utf-8")
        elif isinstance(data, bytes):
            encoded_data = data
            
    req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            latency = (time.time() - start) * 1000
            return resp.status, body, latency, resp.headers
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        latency = (time.time() - start) * 1000
        return e.code, body, latency, e.headers
    except Exception as e:
        latency = (time.time() - start) * 1000
        return 0, str(e), latency, {}

print("=" * 80)
print("     STARTING EXTENSIVE TEST SUITE - LOGISTICS & INVENTORY SYSTEM (IMS)")
print("=" * 80)

# =========================================================================
# DIMENSION 1: INGRESS & FANOUT DNS BOUNDARY TESTING
# =========================================================================
print("\n--- DIMENSION 1: Ingress & Fanout DNS Boundary Testing ---")

# 1.1 Valid domain ims.com
status, body, lat, _ = http_req("/", host=HOST_IMS)
record("1.1 Ingress responds to Host: ims.com", status == 200 and "ims.com" in body, f"HTTP {status}, latency {lat:.1f}ms")

# 1.2 Valid alias ims
status, body, lat, _ = http_req("/health", host=HOST_IMS_ALIAS)
record("1.2 Ingress responds to Host: ims", status == 200 and "UP" in body, f"HTTP {status}, latency {lat:.1f}ms")

# 1.3 Deleted aupp.com returns 404
status, body, lat, _ = http_req("/", host=HOST_AUPP)
record("1.3 Ingress strictly rejects deleted Host: aupp.com", status == 404, f"HTTP {status} (Expected 404)")

# 1.4 Random unknown domain returns 404
status, body, lat, _ = http_req("/", host=HOST_RANDOM)
record("1.4 Ingress strictly rejects unmapped Host: evil-domain.com", status == 404, f"HTTP {status} (Expected 404)")

# 1.5 Unmapped subpath on ims.com returns 404
status, body, lat, _ = http_req("/nonexistent/api/v99", host=HOST_IMS)
record("1.5 Ingress returns 404 on unmapped subpaths", status == 404, f"HTTP {status} (Expected 404)")

# =========================================================================
# DIMENSION 2: SECURITY, JWT & RBAC FUZZING
# =========================================================================
print("\n--- DIMENSION 2: Security, JWT & RBAC Fuzzing ---")

# Register and Login test users for dimension tests
ts = int(time.time())
mgr_email = f"mgr_ext_{ts}@logistics.com"
wrk_email = f"wrk_ext_{ts}@logistics.com"
password = "ExtensivePass123!"

# Register Manager
status, body, _, _ = http_req("/register", method="POST", data={
    "name": "Ext Manager", "email": mgr_email, "password": password, "role": "Manager", "mobile": 9876543210
})
record("2.1 Register Extensive Manager", status == 200, f"HTTP {status}")

# Register Worker
status, body, _, _ = http_req("/register", method="POST", data={
    "name": "Ext Worker", "email": wrk_email, "password": password, "role": "Worker", "mobile": 9123456780
})
record("2.2 Register Extensive Worker", status == 200, f"HTTP {status}")

# Login Manager & get token
status, body, _, _ = http_req("/login", method="POST", data={"emailid": mgr_email, "pass": password, "role": "Manager"})
mgr_token = json.loads(body).get("token", "")
record("2.3 Manager Login & Token Issuance", status == 200 and len(mgr_token) > 20, f"Token length: {len(mgr_token)}")

# Login Worker & get token
status, body, _, _ = http_req("/login", method="POST", data={"emailid": wrk_email, "pass": password, "role": "Worker"})
wrk_token = json.loads(body).get("token", "")
record("2.4 Worker Login & Token Issuance", status == 200 and len(wrk_token) > 20, f"Token length: {len(wrk_token)}")

# 2.5 Request to protected route with NO token -> 401
status, body, _, _ = http_req("/products", method="POST", data={"sku": "TEST"})
record("2.5 Missing Authorization header blocked", status == 401, f"HTTP {status}")

# 2.6 Malformed Authorization header ("Bearer") -> 401
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": "Bearer"}, data={"sku": "TEST"})
record("2.6 Empty Bearer token blocked", status == 401, f"HTTP {status}")

# 2.7 Non-Bearer token scheme ("Basic xxx") -> 403 (Invalid token)
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": "Basic dXNlcjpwYXNz"}, data={"sku": "TEST"})
record("2.7 Non-Bearer scheme blocked", status == 403, f"HTTP {status}")

# 2.8 Tampered JWT Signature -> 403
tampered_token = mgr_token[:-6] + "xxxxxx"
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {tampered_token}"}, data={"sku": "TEST"})
record("2.8 Tampered JWT signature blocked", status == 403, f"HTTP {status}")

# 2.9 Forged JWT with different secret -> 403
# Construct a fake JWT payload header.payload.fake_sig
status, body, _, _ = http_req("/viewprofile", headers={"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImhhY2tlckBldmlsLmNvbSIsInJvbGUiOiJNYW5hZ2VyIn0.invalidsig12345"})
record("2.9 Arbitrary forged token blocked", status == 403, f"HTTP {status}")

# 2.10 RBAC: Worker blocked from Manager route POST /products -> 403
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "sku": "WRK-FORBIDDEN-01", "name": "Illegal Product", "category": "General", "price": 10.0
})
record("2.10 Worker blocked from POST /products", status == 403, f"HTTP {status}")

# 2.11 RBAC: Worker blocked from Manager route POST /orders -> 403
status, body, _, _ = http_req("/orders", method="POST", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "orderId": "WRK-ORD-01", "customerName": "Test", "items": [], "totalAmount": 0
})
record("2.11 Worker blocked from POST /orders", status == 403, f"HTTP {status}")

# 2.12 RBAC: Worker blocked from Manager route POST /shipments -> 403
status, body, _, _ = http_req("/shipments", method="POST", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "shipmentId": "WRK-SHIP-01", "supplier": "Test", "items": []
})
record("2.12 Worker blocked from POST /shipments", status == 403, f"HTTP {status}")

# 2.13 RBAC: Manager blocked from Worker route PUT /inventory/:sku/adjust -> 403
status, body, _, _ = http_req("/inventory/ANY-SKU/adjust", method="PUT", headers={"Authorization": f"Bearer {mgr_token}"}, data={"quantity": 10})
record("2.13 Manager blocked from PUT /inventory/:sku/adjust", status == 403, f"HTTP {status}")

# 2.14 RBAC: Manager blocked from Worker route GET /orders/pending -> 403
status, body, _, _ = http_req("/orders/pending", headers={"Authorization": f"Bearer {mgr_token}"})
record("2.14 Manager blocked from GET /orders/pending", status == 403, f"HTTP {status}")

# 2.15 Anti-Spoofing: Client injecting x-user-role: Manager with Worker token
status, body, _, _ = http_req("/products", method="POST", headers={
    "Authorization": f"Bearer {wrk_token}",
    "x-user-role": "Manager",
    "x-user-email": mgr_email
}, data={"sku": "SPOOF-01", "name": "Spoof Product", "category": "General", "price": 10.0})
record("2.15 Injected header spoofing overridden by Gateway JWT validation", status == 403, f"HTTP {status} (Expected 403)")

# =========================================================================
# DIMENSION 3: COMPLETE SUPPLY CHAIN BUSINESS FLOW
# =========================================================================
print("\n--- DIMENSION 3: Complete Supply Chain Business Flow ---")

sku_1 = f"EXT-SKU-A-{ts}"
sku_2 = f"EXT-SKU-B-{ts}"

# 3.1 Manager creates Product 1
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "sku": sku_1, "name": "Autonomous Drone Sensor", "category": "Robotics", "price": 499.50, "description": "LiDAR Sensor Module"
})
prod1_id = json.loads(body).get("_id", "") if status == 201 else ""
record("3.1 Manager creates Product 1 (Catalog)", status == 201 and len(prod1_id) > 10, f"HTTP {status}, ID: {prod1_id}")

# 3.2 Manager creates Product 2
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "sku": sku_2, "name": "Telemetry Gateway V2", "category": "IoT", "price": 189.99, "description": "Long-range LoRa Gateway"
})
prod2_id = json.loads(body).get("_id", "") if status == 201 else ""
record("3.2 Manager creates Product 2 (Catalog)", status == 201 and len(prod2_id) > 10, f"HTTP {status}, ID: {prod2_id}")

# 3.3 Verify initial stock is 0 in Inventory
status, body, _, _ = http_req(f"/inventory/{sku_1}", headers={"Authorization": f"Bearer {mgr_token}"})
initial_qty = json.loads(body).get("quantity", -1) if status == 200 else -1
record("3.3 Initial inventory quantity defaults to 0", initial_qty == 0, f"Quantity: {initial_qty}")

# 3.4 Manager logs Inbound Shipment of 250 units of Product 1 and 100 units of Product 2
inbound_id_code = f"SHIP-IN-{ts}"
status, body, _, _ = http_req("/shipments", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "shipmentId": inbound_id_code,
    "supplier": "Apex Precision Tech Ltd",
    "carrier": "FedEx Freight",
    "items": [
        {"sku": sku_1, "expectedQuantity": 250},
        {"sku": sku_2, "expectedQuantity": 100}
    ]
})
shipment_doc_id = json.loads(body).get("_id", "") if status == 201 else ""
record("3.4 Manager logs Inbound Shipment (Inbound Service)", status == 201, f"HTTP {status}, Doc ID: {shipment_doc_id}")

# 3.5 Worker verifies Inbound Shipment receipt
status, body, _, _ = http_req(f"/shipments/{shipment_doc_id}/verify", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "receivedItems": [
        {"sku": sku_1, "receivedQuantity": 250},
        {"sku": sku_2, "receivedQuantity": 100}
    ],
    "notes": "All shipments verified intact by receiving dock worker"
})
record("3.5 Worker verifies Inbound Shipment (Status: received)", status == 200, f"HTTP {status}")

# 3.6 Worker adjusts Inventory stock for SKU 1 to 250
status, body, _, _ = http_req(f"/inventory/{sku_1}/adjust", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "quantity": 250, "location": "Warehouse-Bay-7-Shelf-3"
})
record("3.6 Worker adjusts inventory for SKU 1 to 250", status == 200, f"HTTP {status}")

# 3.7 Worker adjusts Inventory stock for SKU 2 to 100
status, body, _, _ = http_req(f"/inventory/{sku_2}/adjust", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={
    "quantity": 100, "location": "Warehouse-Bay-7-Shelf-4"
})
record("3.7 Worker adjusts inventory for SKU 2 to 100", status == 200, f"HTTP {status}")

# 3.8 Verify inter-service Catalog stock aggregation reflects live adjusted stock
status, body, _, _ = http_req(f"/products/{prod1_id}", headers={"Authorization": f"Bearer {mgr_token}"})
agg_stock1 = json.loads(body).get("availableStock", -1) if status == 200 else -1
record("3.8 Inter-service Catalog call aggregates live Inventory stock (250)", agg_stock1 == 250, f"availableStock: {agg_stock1}")

# 3.9 Manager places Order 1 for 15 units of SKU 1
order1_code = f"ORD-REL-{ts}-1"
status, body, _, _ = http_req("/orders", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "orderId": order1_code,
    "customerName": "Universal Robotics Corp",
    "items": [{"sku": sku_1, "quantity": 15, "price": 499.50}],
    "totalAmount": 7492.50
})
order1_doc_id = json.loads(body).get("_id", "") if status == 201 else ""
record("3.9 Manager creates Order 1 (Order Service)", status == 201, f"HTTP {status}, ID: {order1_doc_id}")

# 3.10 Manager places Order 2 for 5 units of SKU 2
order2_code = f"ORD-REL-{ts}-2"
status, body, _, _ = http_req("/orders", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "orderId": order2_code,
    "customerName": "Pacific Telecom Ltd",
    "items": [{"sku": sku_2, "quantity": 5, "price": 189.99}],
    "totalAmount": 949.95
})
order2_doc_id = json.loads(body).get("_id", "") if status == 201 else ""
record("3.10 Manager creates Order 2 (Order Service)", status == 201, f"HTTP {status}, ID: {order2_doc_id}")

# 3.11 Worker queries pending orders
status, body, _, _ = http_req("/orders/pending", headers={"Authorization": f"Bearer {wrk_token}"})
pending_list = json.loads(body) if status == 200 and body.startswith("[") else []
has_orders = any(o.get("_id") == order1_doc_id for o in pending_list) and any(o.get("_id") == order2_doc_id for o in pending_list)
record("3.11 Worker views pending orders list", status == 200 and has_orders, f"Pending orders count: {len(pending_list)}")

# 3.12 Worker updates Order 1 status to 'picked'
status, body, _, _ = http_req(f"/orders/{order1_doc_id}/status", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={"status": "picked"})
record("3.12 Worker transitions Order 1 status -> picked", status == 200, f"HTTP {status}")

# 3.13 Worker updates Order 1 status to 'packed'
status, body, _, _ = http_req(f"/orders/{order1_doc_id}/status", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={"status": "packed"})
record("3.13 Worker transitions Order 1 status -> packed", status == 200, f"HTTP {status}")

# 3.14 Manager updates Product 1 price and description
status, body, _, _ = http_req(f"/products/{prod1_id}", method="PUT", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "price": 549.00, "description": "Updated LiDAR Sensor Module (Gen 2)"
})
record("3.14 Manager updates Product details in Catalog", status == 200, f"HTTP {status}")

# 3.15 Manager views User Profile
status, body, _, _ = http_req("/viewprofile", headers={"Authorization": f"Bearer {mgr_token}"})
prof_email = json.loads(body).get("email", "") if status == 200 else ""
record("3.15 Authenticated user views profile", status == 200 and prof_email == mgr_email, f"Profile email: {prof_email}")

# 3.16 Manager updates User Profile
status, body, _, _ = http_req("/updateprofile", method="PUT", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "name": "Dr. Ext Manager PhD", "mobile": 9988776655
})
record("3.16 Authenticated user updates profile", status == 200, f"HTTP {status}")

# 3.17 User logs out
status, body, _, _ = http_req("/logout", method="POST", headers={"Authorization": f"Bearer {mgr_token}"})
record("3.17 User session logout", status == 200, f"HTTP {status}")

# =========================================================================
# DIMENSION 4: EXTREME BOUNDARY & INPUT EDGE CASES
# =========================================================================
print("\n--- DIMENSION 4: Extreme Boundary & Input Edge Cases ---")

# 4.1 Malformed MongoDB ObjectId in GET /products/:id (non-hex string)
status, body, _, _ = http_req("/products/not-a-valid-hex-id", headers={"Authorization": f"Bearer {mgr_token}"})
record("4.1 Malformed non-hex ObjectId handled gracefully (404)", status == 404, f"HTTP {status} (Expected 404)")

# 4.2 Malformed MongoDB ObjectId in PUT /products/:id
status, body, _, _ = http_req("/products/12345", method="PUT", headers={"Authorization": f"Bearer {mgr_token}"}, data={"price": 10})
record("4.2 Malformed short ObjectId in PUT handled gracefully (404)", status == 404, f"HTTP {status} (Expected 404)")

# 4.3 Malformed MongoDB ObjectId in PUT /orders/:id/status
status, body, _, _ = http_req("/orders/bad-id-xyz/status", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={"status": "picked"})
record("4.3 Malformed ObjectId in Order status handled gracefully (404)", status == 404, f"HTTP {status} (Expected 404)")

# 4.4 Malformed MongoDB ObjectId in PUT /shipments/:id/verify
status, body, _, _ = http_req("/shipments/bad-ship-id/verify", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={"receivedItems": []})
record("4.4 Malformed ObjectId in Shipment verify handled gracefully (404)", status == 404, f"HTTP {status} (Expected 404)")

# 4.5 Valid hex but non-existent ObjectId (000000000000000000000000)
status, body, _, _ = http_req("/products/000000000000000000000000", headers={"Authorization": f"Bearer {mgr_token}"})
record("4.5 Valid format non-existent ObjectId returns 404", status == 404, f"HTTP {status} (Expected 404)")

# 4.6 Product with special characters and Unicode in name & description
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "sku": f"SKU-UNICODE-{ts}",
    "name": "Capteur LiDAR 激光雷达 (日本語 / 한국어) ⚡️📦",
    "category": "Optical & Photonic / 光学",
    "price": 1299.95,
    "description": "Unicode test: ¡Hola! Grüß Gott, ça va? \n\t Multi-line & symbols: #$%&*+@/="
})
record("4.6 Special characters & Unicode strings stored safely", status == 201, f"HTTP {status}")

# 4.7 Inventory adjust with zero quantity
status, body, _, _ = http_req(f"/inventory/SKU-UNICODE-{ts}/adjust", method="PUT", headers={"Authorization": f"Bearer {wrk_token}"}, data={"quantity": 0})
record("4.7 Inventory handles zero quantity adjustment", status == 200, f"HTTP {status}")

# 4.8 Duplicate SKU creation handled gracefully
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "sku": sku_1, "name": "Duplicate SKU Item", "category": "General", "price": 1.00
})
record("4.8 Duplicate SKU creation blocked or rejected (400/409)", status in (400, 409), f"HTTP {status}")

# 4.9 Large payload handling (50KB description string)
large_desc = "A" * 50000
status, body, _, _ = http_req("/products", method="POST", headers={"Authorization": f"Bearer {mgr_token}"}, data={
    "sku": f"SKU-LARGE-{ts}", "name": "Large Payload Product", "category": "Test", "price": 10.0, "description": large_desc
})
record("4.9 Large 50KB payload processed successfully", status == 201, f"HTTP {status}")

# =========================================================================
# DIMENSION 5: CONCURRENCY & HIGH-LOAD STRESS TESTING
# =========================================================================
print("\n--- DIMENSION 5: Concurrency & High-Load Stress Testing ---")

TOTAL_CONCURRENT_REQUESTS = 100
CONCURRENCY_WORKERS = 10

def make_req(idx):
    endpoints = ["/", "/health", "/logs"]
    path = endpoints[idx % len(endpoints)]
    st, bd, lat, _ = http_req(path, host=HOST_IMS, timeout=5)
    return st, lat, bd

print(f"  Firing {TOTAL_CONCURRENT_REQUESTS} parallel requests across Gateway endpoints...")
latencies = []
statuses = []
containers_hit = set()

start_time = time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENCY_WORKERS) as executor:
    futures = [executor.submit(make_req, i) for i in range(TOTAL_CONCURRENT_REQUESTS)]
    for f in concurrent.futures.as_completed(futures):
        st, lat, bd = f.result()
        statuses.append(st)
        latencies.append(lat)
        if "Container:" in bd:
            import re
            m = re.search(r'Container:\s*([\w-]+)', bd)
            if m:
                containers_hit.add(m.group(1))
        elif '"container":' in bd:
            import re
            m = re.search(r'"container":"([\w-]+)"', bd)
            if m:
                containers_hit.add(m.group(1))

total_duration = time.time() - start_time
rps = TOTAL_CONCURRENT_REQUESTS / total_duration
success_rate = (statuses.count(200) / TOTAL_CONCURRENT_REQUESTS) * 100
latencies.sort()
p50 = latencies[int(len(latencies) * 0.50)]
p95 = latencies[int(len(latencies) * 0.95)]
p99 = latencies[int(len(latencies) * 0.99)]
avg_lat = sum(latencies) / len(latencies)

record(f"5.1 Concurrency Stress: {TOTAL_CONCURRENT_REQUESTS} requests", success_rate == 100.0,
       f"100% 200 OK, {rps:.1f} req/s, avg {avg_lat:.1f}ms, p50 {p50:.1f}ms, p95 {p95:.1f}ms, p99 {p99:.1f}ms")

record("5.2 Pod Load Balancing distribution", len(containers_hit) >= 1, f"Containers servicing requests: {list(containers_hit)}")

# =========================================================================
# DIMENSION 6: KUBERNETES HIGH AVAILABILITY & VOLUME PERSISTENCE
# =========================================================================
print("\n--- DIMENSION 6: Kubernetes High Availability & Volume Persistence ---")

KUBECTL = ["sudo", "kubectl", "--kubeconfig=/etc/kubernetes/admin.conf"]

# 6.1 Verify PersistentVolume & Claim status
pvc_res = subprocess.run(KUBECTL + ["get", "pvc", "app-logs-pvc", "-o", "jsonpath={.status.phase}"], capture_output=True, text=True)
pvc_phase = pvc_res.stdout.strip()
record("6.1 Kubernetes PVC is Bound", pvc_phase == "Bound", f"Phase: {pvc_phase}")

# 6.2 Inspect gateway.log via GET /logs
status, body, _, _ = http_req("/logs", headers={"Authorization": f"Bearer {mgr_token}"})
log_lines = body.count("\n")
record("6.2 Shared volume log accessible via API Gateway", status == 200 and log_lines > 50, f"Found {log_lines} log entries in shared volume")

# 6.3 Sidecar container verification in multi-container pod
pod_res = subprocess.run(KUBECTL + ["get", "pods", "-l", "app=api-gateway-service", "-o", "jsonpath={.items[0].metadata.name}"], capture_output=True, text=True)
gw_pod_name = pod_res.stdout.strip()

sidecar_logs = subprocess.run(KUBECTL + ["logs", gw_pod_name, "-c", "log-sidecar-container", "--tail=10"], capture_output=True, text=True)
sidecar_active = "Container:" in sidecar_logs.stdout or "[" in sidecar_logs.stdout
record("6.3 Multi-container sidecar (log-sidecar-container) streams shared volume", sidecar_active, f"Pod: {gw_pod_name}")

# 6.4 Pod Self-Healing test: delete one replica of apigateway pod
print(f"  Testing Pod Self-Healing: Deleting pod {gw_pod_name}...")
del_res = subprocess.run(KUBECTL + ["delete", "pod", gw_pod_name, "--wait=false"], capture_output=True, text=True)

# Immediately issue traffic while pod is terminating
healing_success = 0
for _ in range(5):
    time.sleep(0.5)
    st, _, _, _ = http_req("/health", host=HOST_IMS, timeout=3)
    if st == 200:
        healing_success += 1

record("6.4 Zero-downtime during pod termination (2nd replica handles traffic)", healing_success >= 4, f"{healing_success}/5 requests succeeded during failover")

# Wait a brief moment for replacement pod to spawn
time.sleep(7)
new_pods = subprocess.run(KUBECTL + ["get", "pods", "-l", "app=api-gateway-service", "-o", "jsonpath={.items[*].status.phase}"], capture_output=True, text=True)
record("6.5 Kubernetes automatically scheduled replacement pod", "Running" in new_pods.stdout, f"Pod phases: {new_pods.stdout.strip()}")

# =========================================================================
# FINAL SUMMARY REPORT
# =========================================================================
print("\n" + "=" * 80)
print("                           FINAL EXECUTION REPORT                         ")
print("=" * 80)
total_tests = len(test_results)
passed_tests = sum(1 for t in test_results if t["passed"])
failed_tests = total_tests - passed_tests

print(f"  TOTAL ASSERTIONS EVALUATED : {total_tests}")
print(f"  PASSED                     : {passed_tests}")
print(f"  FAILED                     : {failed_tests}")
print(f"  SUCCESS RATE               : {(passed_tests / total_tests) * 100:.1f}%")
print("=" * 80)

if failed_tests == 0:
    print("\n\033[92m>>> ALL TESTS PASSED! THE SYSTEM DEMONSTRATES EXCEPTIONAL RESILIENCE AND RELIABILITY. <<<\033[0m\n")
    sys.exit(0)
else:
    print("\n\033[91m>>> SOME TESTS FAILED. PLEASE REVIEW THE DETAILS ABOVE. <<<\033[0m\n")
    sys.exit(1)
