const express = require('express');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";
const PORT = process.env.PORT || 5003;

// 1. Connect to MongoDB
mongoose.connect(MONGO_URI)
  .then(() => console.log('Product Catalog Service Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// 2. Define the Product Schema
const productSchema = new mongoose.Schema({
  sku: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  description: { type: String, required: true },
  price: { type: Number, required: true },
  category: { type: String }
});

const Product = mongoose.model('Product', productSchema, 'Catalog');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Catalog Service' }));

// --- APIs ---

// CREATE API - POST /products (Manager only)
app.post('/products', async (req, res) => {
  try {
    if (!req.body.sku || !req.body.name || req.body.price === undefined) {
      return res.status(400).json({ error: "sku, name, and price are required" });
    }

    // Defensive check for duplicate SKU
    const existing = await Product.findOne({ sku: req.body.sku });
    if (existing) {
      return res.status(400).json({ error: "Product SKU already exists" });
    }

    const newProduct = new Product({
      sku: req.body.sku,
      name: req.body.name,
      description: req.body.description || '',
      price: req.body.price,
      category: req.body.category || 'General'
    });
    
    const savedProduct = await newProduct.save();
    return res.status(201).json(savedProduct);
  } catch (error) {
    console.error("Create Product Error:", error);
    if (error.code === 11000) {
      return res.status(400).json({ error: "Product SKU already exists" });
    }
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// READ API - GET /products/:id (Manager & Worker)
app.get('/products/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ message: "Product Not Found" });
    }

    const product = await Product.findById(req.params.id);

    if (!product) {
      return res.status(404).json({ message: "Product Not Found" });
    }

    // Call Inventory Microservice (Port 5004)
    let availableQuantity = 0;
    try {
      const trackingUrl = process.env.TRACKING_URL || 'http://inventory-service:5004';
      const inventoryResponse = await fetch(`${trackingUrl}/inventory/${product.sku}`);
      if (inventoryResponse.ok) {
        const inventoryData = await inventoryResponse.json();
        availableQuantity = inventoryData.quantity !== undefined ? inventoryData.quantity : 0;
      }
    } catch (inventoryError) {
      console.log("Could not reach Inventory service. Defaulting to 0.");
    }

    const combinedResponse = {
      _id: product._id,
      sku: product.sku,
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      availableStock: availableQuantity
    };

    return res.status(200).json(combinedResponse);
  } catch (error) {
    console.error("Get Product Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// UPDATE API - PUT /products/:id (Manager only)
app.put('/products/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ message: "Product Not Found to Update" });
    }

    const updatedProduct = await Product.findByIdAndUpdate(
      req.params.id, 
      req.body, 
      { new: true }
    );

    if (!updatedProduct) {
      return res.status(404).json({ message: "Product Not Found to Update" });
    }
    return res.status(200).json({ message: "Product successfully updated", product: updatedProduct });
  } catch (error) {
    console.error("Update Product Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// START THE EXPRESS SERVER
app.listen(PORT, () => 
  console.log(`EXPRESS Server Started at Port No: ${PORT}`)
);
