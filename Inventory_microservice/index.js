const express = require('express');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";
const PORT = process.env.PORT || 5004;

// 1. Connect to MongoDB
mongoose.connect(MONGO_URI)
  .then(() => console.log('Inventory Tracking Service Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// 2. Define the Inventory Schema
const inventorySchema = new mongoose.Schema({
  sku: { type: String, required: true, unique: true },
  quantity: { type: Number, required: true, default: 0 }
});

const Inventory = mongoose.model('Inventory', inventorySchema, 'Inventory');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Inventory Service' }));

// --- APIs ---

// READ API - GET /inventory/:sku (Manager & Worker)
app.get('/inventory/:sku', async (req, res) => {
  try {
    let item = await Inventory.findOne({ sku: req.params.sku });
    
    if (!item) {
      item = { sku: req.params.sku, quantity: 0 };
    }
    return res.status(200).json(item);
  } catch (error) {
    console.error("Get Inventory Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// ADJUST API - PUT /inventory/:sku/adjust (Worker only)
app.put('/inventory/:sku/adjust', async (req, res) => {
  try {
    if (req.body.quantity === undefined) {
      return res.status(400).json({ error: "quantity is required" });
    }

    const updatedInventory = await Inventory.findOneAndUpdate(
      { sku: req.params.sku }, 
      { quantity: req.body.quantity },
      { new: true, upsert: true }
    );

    return res.status(200).json({ message: "Stock successfully adjusted", inventory: updatedInventory });
  } catch (error) {
    console.error("Adjust Inventory Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// START THE EXPRESS SERVER
app.listen(PORT, () => 
  console.log(`EXPRESS Server Started at Port No: ${PORT}`)
);
