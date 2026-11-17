#!/bin/bash
set -u

export PATH="/var/lib/minikube/binaries/v1.37.0:/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="/etc/kubernetes/admin.conf"

INGRESS_IP="192.168.49.2"
HOST_HEADER="Host: ims.com"
BASE_URL="http://$INGRESS_IP"

PASSED=0
FAILED=0

assert_equal() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" == "$actual" ]; then
    echo "  [PASS] $test_name (got: $actual)"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $test_name (expected: $expected, got: $actual)"
    FAILED=$((FAILED + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local substring="$2"
  local full_text="$3"
  if [[ "$full_text" == *"$substring"* ]]; then
    echo "  [PASS] $test_name (found expected substring)"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $test_name (expected to contain '$substring' in '$full_text')"
    FAILED=$((FAILED + 1))
  fi
}

echo "=========================================================================="
echo "      MICROSERVICES & KUBERNETES COMPREHENSIVE TEST SUITE (47 SCENARIOS)   "
echo "=========================================================================="

TS=$(date +%s)
MGR_EMAIL="mgr_test_${TS}@ims.com"
WRK_EMAIL="wrk_test_${TS}@ims.com"
SKU_ID="SKU-AUTO-${TS}"

echo ""
echo "=== SECTION 1: Gateway Base & Health Checks ==="
# Scenario 1: Root endpoint
RES=$(curl -s -w "\n%{http_code}" -H "$HOST_HEADER" "$BASE_URL/")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 1: GET / HTTP 200" "200" "$STATUS"
assert_contains "Scenario 1: GET / contains domain ims.com" '"domain":"ims.com"' "$BODY"

# Scenario 2: Health endpoint
RES=$(curl -s -w "\n%{http_code}" -H "$HOST_HEADER" "$BASE_URL/health")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 2: GET /health HTTP 200" "200" "$STATUS"
assert_contains "Scenario 2: GET /health status UP" '"status":"UP"' "$BODY"

echo ""
echo "=== SECTION 2: User Registration (Positive & Negative) ==="
# Scenario 3: Manager Registration
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"name\":\"Manager Carol\",\"email\":\"$MGR_EMAIL\",\"password\":\"Secr3t!\",\"mobile\":98765432,\"role\":\"Manager\"}" \
  "$BASE_URL/register")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 3: POST /register Manager HTTP 200" "200" "$STATUS"
assert_contains "Scenario 3: MongoDB insert message" "DOCUMENT INSERTED IN MONGODB DATABASE" "$BODY"

# Scenario 4: Worker Registration
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"name\":\"Worker Dave\",\"email\":\"$WRK_EMAIL\",\"password\":\"Secr3t!\",\"mobile\":87654321,\"role\":\"Worker\"}" \
  "$BASE_URL/register")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 4: POST /register Worker HTTP 200" "200" "$STATUS"

# Scenario 5: Duplicate Registration (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"name\":\"Duplicate\",\"email\":\"$MGR_EMAIL\",\"password\":\"Secr3t!\",\"mobile\":11111111,\"role\":\"Manager\"}" \
  "$BASE_URL/register")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 5: Duplicate registration HTTP 400" "400" "$STATUS"
assert_contains "Scenario 5: Email already exists message" "EMAIL ALREADY EXISTS" "$BODY"

# Scenario 6: Missing email in registration (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"name\":\"No Email\",\"password\":\"Secr3t!\",\"mobile\":11111111,\"role\":\"Manager\"}" \
  "$BASE_URL/register")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 6: Missing email HTTP 400" "400" "$STATUS"

# Scenario 7: Missing password in registration (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"name\":\"No Pass\",\"email\":\"nopass_${TS}@ims.com\",\"mobile\":11111111,\"role\":\"Manager\"}" \
  "$BASE_URL/register")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 7: Missing password HTTP 400" "400" "$STATUS"

echo ""
echo "=== SECTION 3: Authentication & Login (Positive & Negative) ==="
# Scenario 8: Successful Manager Login
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"emailid\":\"$MGR_EMAIL\",\"password\":\"Secr3t!\",\"role\":\"Manager\"}" \
  "$BASE_URL/login")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 8: Manager Login HTTP 200" "200" "$STATUS"
MGR_TOKEN=$(echo "$BODY" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
assert_contains "Scenario 8: Token exists in response" "eyJ" "$MGR_TOKEN"

# Scenario 9: Successful Worker Login
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"emailid\":\"$WRK_EMAIL\",\"password\":\"Secr3t!\",\"role\":\"Worker\"}" \
  "$BASE_URL/login")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 9: Worker Login HTTP 200" "200" "$STATUS"
WRK_TOKEN=$(echo "$BODY" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
assert_contains "Scenario 9: Token exists in response" "eyJ" "$WRK_TOKEN"

# Scenario 10: Login Wrong Password (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"emailid\":\"$MGR_EMAIL\",\"password\":\"wrongpassword\",\"role\":\"Manager\"}" \
  "$BASE_URL/login")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 10: Wrong password HTTP 400" "400" "$STATUS"

# Scenario 11: Login Non-existent User (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"emailid\":\"ghost_${TS}@ims.com\",\"password\":\"Secr3t!\",\"role\":\"Manager\"}" \
  "$BASE_URL/login")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 11: Non-existent user HTTP 400" "400" "$STATUS"

# Scenario 12: Login Role Mismatch (Negative)
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"emailid\":\"$MGR_EMAIL\",\"password\":\"Secr3t!\",\"role\":\"Worker\"}" \
  "$BASE_URL/login")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 12: Role mismatch HTTP 400" "400" "$STATUS"

echo ""
echo "=== SECTION 4: Token & Header Security Checks ==="
# Scenario 13: Missing token on protected endpoint
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -d "{\"sku\":\"$SKU_ID\",\"name\":\"Test Item\"}" \
  "$BASE_URL/products")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 13: Missing token HTTP 401" "401" "$STATUS"
assert_contains "Scenario 13: Please send token message" "Please send token" "$BODY"

# Scenario 14: Invalid/Fake token on protected endpoint
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer this.is.an.invalid.token" \
  -d "{\"sku\":\"$SKU_ID\",\"name\":\"Test Item\"}" \
  "$BASE_URL/products")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 14: Invalid token HTTP 403" "403" "$STATUS"
assert_contains "Scenario 14: Invalid token message" "Invalid token" "$BODY"

echo ""
echo "=== SECTION 5: Role-Based Access Control (RBAC) Protections ==="
# Scenario 15: Worker blocked from Manager POST /products
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"sku\":\"$SKU_ID\",\"name\":\"Forbidden Item\"}" \
  "$BASE_URL/products")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 15: Worker blocked from POST /products HTTP 403" "403" "$STATUS"

# Scenario 16: Worker blocked from Manager POST /orders
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"customerName\":\"Test\",\"itemSku\":\"$SKU_ID\",\"quantity\":1}" \
  "$BASE_URL/orders")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 16: Worker blocked from POST /orders HTTP 403" "403" "$STATUS"

# Scenario 17: Worker blocked from Manager POST /shipments
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"supplierName\":\"Test\",\"itemSku\":\"$SKU_ID\",\"quantity\":1}" \
  "$BASE_URL/shipments")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 17: Worker blocked from POST /shipments HTTP 403" "403" "$STATUS"

# Scenario 18: Manager blocked from Worker PUT /inventory/:sku/adjust
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"quantity\":100}" \
  "$BASE_URL/inventory/$SKU_ID/adjust")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 18: Manager blocked from PUT /inventory/:sku/adjust HTTP 403" "403" "$STATUS"

# Scenario 19: Manager blocked from Worker GET /orders/pending
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  "$BASE_URL/orders/pending")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 19: Manager blocked from GET /orders/pending HTTP 403" "403" "$STATUS"

echo ""
echo "=== SECTION 6: Product Catalog & Live Stock Aggregation ==="
# Scenario 20: Manager Creates Product
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"sku\":\"$SKU_ID\",\"name\":\"4K Ultra Monitor\",\"description\":\"27-inch IPS UHD\",\"price\":349.99,\"category\":\"Monitors\"}" \
  "$BASE_URL/products")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 20: Manager creates product HTTP 201" "201" "$STATUS"
PROD_ID=$(echo "$BODY" | grep -o '"_id":"[^"]*' | cut -d'"' -f4)
assert_contains "Scenario 20: Created product has valid ID" "6" "$PROD_ID"

# Scenario 21: Initial Stock Check (should be 0)
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  "$BASE_URL/inventory/$SKU_ID")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 21: View Initial Stock HTTP 200" "200" "$STATUS"
assert_contains "Scenario 21: Initial quantity 0" '"quantity":0' "$BODY"

# Scenario 22: Worker Adjusts Stock to 180
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"quantity\":180}" \
  "$BASE_URL/inventory/$SKU_ID/adjust")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 22: Worker adjusts stock HTTP 200" "200" "$STATUS"
assert_contains "Scenario 22: Stock adjusted message" "Stock successfully adjusted" "$BODY"
assert_contains "Scenario 22: New quantity 180" '"quantity":180' "$BODY"

# Scenario 23: Catalog Aggregation (GET /products/:id returns live availableStock: 180)
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  "$BASE_URL/products/$PROD_ID")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 23: GET /products/:id HTTP 200" "200" "$STATUS"
assert_contains "Scenario 23: availableStock equals 180" '"availableStock":180' "$BODY"

# Scenario 24: Manager Updates Product (PUT /products/:id)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"price\":329.99,\"description\":\"27-inch IPS UHD HDR400\"}" \
  "$BASE_URL/products/$PROD_ID")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 24: Manager updates product HTTP 200" "200" "$STATUS"
assert_contains "Scenario 24: Product successfully updated" "Product successfully updated" "$BODY"
assert_contains "Scenario 24: New price 329.99" '329.99' "$BODY"

# Scenario 25: Worker blocked from updating product (Negative)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"price\":199.99}" \
  "$BASE_URL/products/$PROD_ID")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 25: Worker blocked from PUT /products/:id HTTP 403" "403" "$STATUS"

# Scenario 26: Non-existent product GET (Negative)
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  "$BASE_URL/products/600000000000000000000000")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 26: Non-existent product GET HTTP 404" "404" "$STATUS"

# Scenario 27: Non-existent product PUT (Negative)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"price\":100}" \
  "$BASE_URL/products/600000000000000000000000")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 27: Non-existent product PUT HTTP 404" "404" "$STATUS"

echo ""
echo "=== SECTION 7: Order Fulfillment Lifecycle ==="
# Scenario 28: Manager Creates Order
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"customerName\":\"Johnathan Smith\",\"itemSku\":\"$SKU_ID\",\"quantity\":3}" \
  "$BASE_URL/orders")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 28: Create Order HTTP 201" "201" "$STATUS"
ORDER_ID=$(echo "$BODY" | grep -o '"_id":"[^"]*' | cut -d'"' -f4)
assert_contains "Scenario 28: Order initial status pending" '"status":"pending"' "$BODY"

# Scenario 29: Worker Views Pending Orders
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  "$BASE_URL/orders/pending")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 29: View Pending Orders HTTP 200" "200" "$STATUS"
assert_contains "Scenario 29: Pending orders contain newly created order ID" "$ORDER_ID" "$BODY"

# Scenario 30: Worker Updates Order Status to picked
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"status\":\"picked\"}" \
  "$BASE_URL/orders/$ORDER_ID/status")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 30: Update Order to picked HTTP 200" "200" "$STATUS"
assert_contains "Scenario 30: Status is picked" '"status":"picked"' "$BODY"

# Scenario 31: Worker Updates Order Status to packed
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"status\":\"packed\"}" \
  "$BASE_URL/orders/$ORDER_ID/status")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 31: Update Order to packed HTTP 200" "200" "$STATUS"
assert_contains "Scenario 31: Status is packed" '"status":"packed"' "$BODY"

# Scenario 32: Non-existent order update (Negative)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"status\":\"packed\"}" \
  "$BASE_URL/orders/600000000000000000000000/status")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 32: Non-existent order HTTP 404" "404" "$STATUS"

echo ""
echo "=== SECTION 8: Inbound Receiving Lifecycle ==="
# Scenario 33: Manager Creates Inbound Shipment
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"supplierName\":\"Asia Electronics Co\",\"itemSku\":\"$SKU_ID\",\"quantity\":500}" \
  "$BASE_URL/shipments")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 33: Create Shipment HTTP 201" "201" "$STATUS"
SHIP_ID=$(echo "$BODY" | grep -o '"_id":"[^"]*' | cut -d'"' -f4)
assert_contains "Scenario 33: Initial shipment status pending" '"status":"pending"' "$BODY"

# Scenario 34: Worker Verifies Shipment
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  "$BASE_URL/shipments/$SHIP_ID/verify")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 34: Verify Shipment HTTP 200" "200" "$STATUS"
assert_contains "Scenario 34: Verified status received" '"status":"received"' "$BODY"

# Scenario 35: Non-existent shipment verify (Negative)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  "$BASE_URL/shipments/600000000000000000000000/verify")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 35: Non-existent shipment HTTP 404" "404" "$STATUS"

echo ""
echo "=== SECTION 9: User Profile Lifecycle ==="
# Scenario 36: View Profile
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"emailid\":\"$MGR_EMAIL\"}" \
  "$BASE_URL/viewprofile")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 36: View Profile HTTP 200" "200" "$STATUS"
assert_contains "Scenario 36: Contains email" "$MGR_EMAIL" "$BODY"
assert_contains "Scenario 36: Contains role Manager" '"role":"Manager"' "$BODY"

# Scenario 37: Update Profile (Name & Mobile)
RES=$(curl -s -w "\n%{http_code}" -X PUT -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"emailid\":\"$MGR_EMAIL\",\"name\":\"Carol Chief Logistics Officer\",\"mobile\":77665544}" \
  "$BASE_URL/updateprofile")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 37: Update Profile HTTP 200" "200" "$STATUS"
assert_contains "Scenario 37: Success message" "Profile updated successfully" "$BODY"
assert_contains "Scenario 37: Updated name in body" "Carol Chief Logistics Officer" "$BODY"

# Scenario 38: View Profile after Update (verifies persistence in MongoDB)
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"emailid\":\"$MGR_EMAIL\"}" \
  "$BASE_URL/viewprofile")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 38: View Profile post-update HTTP 200" "200" "$STATUS"
assert_contains "Scenario 38: Confirmed new mobile" "77665544" "$BODY"
assert_contains "Scenario 38: Confirmed new name" "Carol Chief Logistics Officer" "$BODY"

# Scenario 39: Worker Views Profile
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WRK_TOKEN" \
  -d "{\"emailid\":\"$WRK_EMAIL\"}" \
  "$BASE_URL/viewprofile")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 39: Worker Views Profile HTTP 200" "200" "$STATUS"
assert_contains "Scenario 39: Role is Worker" '"role":"Worker"' "$BODY"

# Scenario 40: View non-existent user profile (Negative)
RES=$(curl -s -w "\n%{http_code}" -X GET -H "$HOST_HEADER" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MGR_TOKEN" \
  -d "{\"emailid\":\"nonexistent_${TS}@ims.com\"}" \
  "$BASE_URL/viewprofile")
STATUS=$(echo "$RES" | tail -n1)
assert_equal "Scenario 40: Non-existent profile HTTP 404" "404" "$STATUS"

echo ""
echo "=== SECTION 10: Session Logout ==="
# Scenario 41: Logout
RES=$(curl -s -w "\n%{http_code}" -X POST -H "$HOST_HEADER" "$BASE_URL/logout")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 41: Logout HTTP 200" "200" "$STATUS"
assert_contains "Scenario 41: Logout success message" "Logged out successfully" "$BODY"

echo ""
echo "=== SECTION 11: Kubernetes Volume & Multi-Container Shared Storage ==="
# Scenario 42: Gateway GET /logs endpoint reads from volume
RES=$(curl -s -w "\n%{http_code}" -H "$HOST_HEADER" "$BASE_URL/logs")
STATUS=$(echo "$RES" | tail -n1)
BODY=$(echo "$RES" | sed '$d')
assert_equal "Scenario 42: GET /logs HTTP 200" "200" "$STATUS"
assert_contains "Scenario 42: Log contains recent request" "POST /register" "$BODY"

# Scenario 43: Direct inspection of persistent volume
VOL_PVC=$(kubectl get pvc app-logs-pvc -o jsonpath='{.status.phase}')
assert_equal "Scenario 43: PVC status Bound" "Bound" "$VOL_PVC"

# Scenario 44: Log file accessible via sidecar container directly
SIDECAR_OUTPUT=$(kubectl exec deployment/apigateway-deployment -c log-sidecar-container -- cat /var/log/app/gateway.log 2>/dev/null)
assert_contains "Scenario 44: Sidecar container accesses gateway.log" "POST /register" "$SIDECAR_OUTPUT"

# Scenario 45: Sidecar process is running tail -F on shared volume
SIDECAR_LOGS=$(kubectl logs deployment/apigateway-deployment -c log-sidecar-container --tail=15 2>/dev/null)
assert_contains "Scenario 45: Sidecar streaming logs from shared volume" "Container:" "$SIDECAR_LOGS"

echo ""
echo "=== SECTION 12: Cluster Isolation & Fanout Ingress Verification ==="
# Scenario 46: Verify Ingress host is ims.com
INGRESS_HOST=$(kubectl get ingress ims-fanout-ingress -o jsonpath='{.spec.rules[0].host}')
assert_equal "Scenario 46: Ingress host configured as ims.com" "ims.com" "$INGRESS_HOST"

# Scenario 47: Verify backend services are strictly ClusterIP (not NodePort or LoadBalancer)
NON_CLUSTER_IP=$(kubectl get svc --no-headers | grep -v "api-gateway-service" | grep -v "kubernetes" | grep -v "ClusterIP" | wc -l)
assert_equal "Scenario 47: All backend microservices are internal ClusterIP only (count of non-Gateway NodePorts = 0)" "0" "$NON_CLUSTER_IP"

echo ""
echo "=========================================================================="
echo "                           TEST EXECUTION SUMMARY                         "
echo "=========================================================================="
echo "  TOTAL TESTS : $((PASSED + FAILED))"
echo "  PASSED      : $PASSED"
echo "  FAILED      : $FAILED"
echo "=========================================================================="

if [ "$FAILED" -eq 0 ]; then
  echo ">>> ALL 47 SCENARIOS PASSED WITH 100% SUCCESS! <<<"
  exit 0
else
  echo ">>> SOME TESTS FAILED! CHECK OUTPUT ABOVE. <<<"
  exit 1
fi
