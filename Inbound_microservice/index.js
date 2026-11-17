const express = require('express');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";
const PORT = process.env.PORT || 5006;

// 1. Connect to MongoDB
mongoose.connect(MONGO_URI)
  .then(() => console.log('Inbound Receiving Service Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// 2. Define the Shipment Schema
const shipmentSchema = new mongoose.Schema({
  supplierName: { type: String, required: true },
  itemSku: { type: String, required: true },
  quantity: { type: Number, required: true },
  status: { type: String, default: 'pending' }
}, { timestamps: true });

const Shipment = mongoose.model('Shipment', shipmentSchema, 'shipment_collections');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Inbound Service' }));

// --- APIs ---

// CREATE API - POST /shipments (Manager only)
app.post('/shipments', async (req, res) => {
  try {
    const supplierName = req.body.supplierName || req.body.supplier;
    const itemSku = req.body.itemSku || req.body.sku || (req.body.items && req.body.items[0] && (req.body.items[0].sku || req.body.items[0].itemSku));
    const quantity = req.body.quantity !== undefined ? req.body.quantity : (req.body.items && req.body.items[0] && (req.body.items[0].expectedQuantity !== undefined ? req.body.items[0].expectedQuantity : req.body.items[0].quantity));

    if (!supplierName || !itemSku || quantity === undefined) {
      return res.status(400).json({ error: "supplierName, itemSku, and quantity are required" });
    }

    const newShipment = new Shipment({
      supplierName,
      itemSku,
      quantity,
      status: 'pending'
    });
    
    const savedShipment = await newShipment.save();
    return res.status(201).json(savedShipment);
  } catch (error) {
    console.error("Create Shipment Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// VERIFY API - PUT /shipments/:id/verify (Worker only)
app.put('/shipments/:id/verify', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(404).json({ message: "Shipment Not Found" });
    }

    const updatedShipment = await Shipment.findByIdAndUpdate(
      req.params.id, 
      { status: 'received' },
      { new: true }
    );

    if (!updatedShipment) {
      return res.status(404).json({ message: "Shipment Not Found" });
    }
    return res.status(200).json({ message: "Shipment successfully verified", shipment: updatedShipment });
  } catch (error) {
    console.error("Verify Shipment Error:", error);
    return res.status(500).json({ error: error.message || "Server Error" });
  }
});

// START THE EXPRESS SERVER
app.listen(PORT, () => 
  console.log(`EXPRESS Server Started at Port No: ${PORT}`)
);
