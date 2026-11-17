const express = require('express');
const os = require('os');
const fs = require('fs');
const path = require('path');
const httpProxy = require('http-proxy');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const app = express();
const proxy = httpProxy.createProxyServer();

const PORT = process.env.PORT || 4000;
const JWT_SECRETE = process.env.JWT_SECRETE || '347186591486#^%%ABCF*##GHE';

// Kubernetes Shared Volume Logging
const LOG_DIR = process.env.LOG_DIR || '/var/log/app';
const LOG_FILE = process.env.LOG_FILE_PATH || path.join(LOG_DIR, 'gateway.log');

try {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
} catch (err) {
  console.warn(`[API Gateway] Warning: Could not create log directory ${LOG_DIR}: ${err.message}`);
}

// Global Logging Middleware (Console + Shared Volume)
app.use((req, res, next) => {
  const logMessage = `[${new Date().toISOString()}] Container: ${os.hostname()} | ${req.method} ${req.originalUrl} | IP: ${req.ip}\n`;
  console.log(logMessage.trim());
  try {
    fs.appendFileSync(LOG_FILE, logMessage);
  } catch (err) {
    // Non-fatal if filesystem is temporarily unavailable
  }
  next();
});

// Authentication Middleware
function authToken(req, res, next) {
  const header = req?.headers.authorization;
  const token = header && header.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: "Please send token" });
  }

  jwt.verify(token, JWT_SECRETE, (err, user) => {
    if (err) {
      return res.status(403).json({ message: "Invalid token" });
    }
    req.user = user;
    if (user.emailid) req.headers['x-user-email'] = user.emailid;
    if (user.role) req.headers['x-user-role'] = user.role;
    next();
  });
}

// Role-based auth middleware accepting an array of allowed roles
function authRole(roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: "Unauthorized" });
    }
    next();
  };
}

// TARGET URLS FOR MICROSERVICES (Kubernetes Service DNS with local fallbacks)
const REGISTRATION_URL = process.env.REGISTRATION_URL || 'http://registration-service:5001';
const LOGIN_URL = process.env.LOGIN_URL || 'http://login-service:5002';
const PRODUCT_URL = process.env.PRODUCT_URL || 'http://catalog-service:5003';
const TRACKING_URL = process.env.TRACKING_URL || 'http://inventory-service:5004';
const ORDER_URL = process.env.ORDER_URL || 'http://order-service:5005';
const INBOUND_URL = process.env.INBOUND_URL || 'http://inbound-service:5006';
const USER_URL = process.env.USER_URL || 'http://userprofile-service:5007';

// 0. Base / Health / Logs Endpoints
app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Logistics & Inventory Management System API Gateway',
    status: 'UP',
    domain: process.env.DOMAIN_NAME || 'ims.com',
    container: os.hostname(),
    gateway_port: PORT
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', service: 'API Gateway', timestamp: new Date() });
});

// Demonstrates reading logs stored in Kubernetes Volume
app.get('/logs', (req, res) => {
  try {
    if (fs.existsSync(LOG_FILE)) {
      const logs = fs.readFileSync(LOG_FILE, 'utf8');
      res.type('text/plain').send(logs);
    } else {
      res.status(404).send('Log file not found at ' + LOG_FILE);
    }
  } catch (err) {
    res.status(500).send(`Error reading log file: ${err.message}`);
  }
});

// 1. Registration Service
app.post('/register', (req, res) => proxy.web(req, res, { target: REGISTRATION_URL }));

// 2. Login & Logout Service
app.post('/login', (req, res) => proxy.web(req, res, { target: LOGIN_URL }));
app.post('/logout', (req, res) => proxy.web(req, res, { target: LOGIN_URL }));

// 3. User Profile Service
app.get('/viewprofile', authToken, (req, res) => proxy.web(req, res, { target: USER_URL }));
app.put('/updateprofile', authToken, (req, res) => proxy.web(req, res, { target: USER_URL }));

// 4. Product Catalog Service
app.post('/products', authToken, authRole(['Manager']), (req, res) => proxy.web(req, res, { target: PRODUCT_URL }));
app.get('/products/:id', authToken, authRole(['Manager', 'Worker']), (req, res) => proxy.web(req, res, { target: PRODUCT_URL }));
app.put('/products/:id', authToken, authRole(['Manager']), (req, res) => proxy.web(req, res, { target: PRODUCT_URL }));

// 5. Inventory Tracking Service
app.get('/inventory/:sku', authToken, authRole(['Manager', 'Worker']), (req, res) => proxy.web(req, res, { target: TRACKING_URL }));
app.put('/inventory/:sku/adjust', authToken, authRole(['Worker']), (req, res) => proxy.web(req, res, { target: TRACKING_URL }));

// 6. Order Fulfillment Service
app.post('/orders', authToken, authRole(['Manager']), (req, res) => proxy.web(req, res, { target: ORDER_URL }));
app.get('/orders/pending', authToken, authRole(['Worker']), (req, res) => proxy.web(req, res, { target: ORDER_URL }));
app.put('/orders/:id/status', authToken, authRole(['Worker']), (req, res) => proxy.web(req, res, { target: ORDER_URL }));

// 7. Inbound Receiving Service
app.post('/shipments', authToken, authRole(['Manager']), (req, res) => proxy.web(req, res, { target: INBOUND_URL }));
app.put('/shipments/:id/verify', authToken, authRole(['Worker']), (req, res) => proxy.web(req, res, { target: INBOUND_URL }));

// Error handling for proxy
proxy.on('error', function (err, req, res) {
  console.error("[API Gateway] Proxy Error:", err.message);
  if (!res.headersSent) {
    res.status(502).json({ error: 'Bad Gateway', details: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`API Gateway Service is running on PORT NO: ${PORT}`);
  console.log(`Writing logs to Kubernetes Volume at: ${LOG_FILE}`);
});
