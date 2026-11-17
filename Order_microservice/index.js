const express = require('express');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";
const PORT = process.env.PORT || 5005;

// 1. Connect to MongoDB
mongoose.connect(MONGO_URI)
    .then(() => console.log('Order Fulfillment Service Connected to MongoDB'))
    .catch(err => console.error('MongoDB connection error:', err));

// 2. Define the Order Schema
const orderSchema = new mongoose.Schema({
    customerName: { type: String, required: true },
    itemSku: { type: String, required: true },
    quantity: { type: Number, required: true },
    status: { type: String, default: 'pending' }
}, { timestamps: true });

const Order = mongoose.model('Order', orderSchema, 'Fulfillment');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Order Service' }));

// --- APIs ---

// CREATE ORDER API - POST /orders (Manager only)
app.post('/orders', async (req, res) => {
    try {
        const customerName = req.body.customerName;
        const itemSku = req.body.itemSku || req.body.sku || (req.body.items && req.body.items[0] && (req.body.items[0].sku || req.body.items[0].itemSku));
        const quantity = req.body.quantity !== undefined ? req.body.quantity : (req.body.items && req.body.items[0] && req.body.items[0].quantity);

        if (!customerName || !itemSku || quantity === undefined) {
            return res.status(400).json({ error: "customerName, itemSku, and quantity are required" });
        }

        const newOrder = new Order({
            customerName,
            itemSku,
            quantity,
            status: 'pending'
        });
        
        const savedOrder = await newOrder.save();
        return res.status(201).json(savedOrder);
    } catch (error) {
        console.error("Create Order Error:", error);
        return res.status(500).json({ error: error.message || "Server Error" });
    }
});

// VIEW PENDING ORDERS API - GET /orders/pending (Worker only)
app.get('/orders/pending', async (req, res) => {
    try {
        const pendingOrders = await Order.find({ status: 'pending' });
        return res.status(200).json(pendingOrders);
    } catch (error) {
        console.error("Get Pending Orders Error:", error);
        return res.status(500).json({ error: error.message || "Server Error" });
    }
});

// UPDATE STATUS API - PUT /orders/:id/status (Worker only)
app.put('/orders/:id/status', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
            return res.status(404).json({ message: "Order Not Found to Update" });
        }

        const updatedOrder = await Order.findByIdAndUpdate(
            req.params.id, 
            { status: req.body.status },
            { new: true }
        );
        
        if (!updatedOrder) {
            return res.status(404).json({ message: "Order Not Found to Update" });
        }
        return res.status(200).json({ message: "Order status successfully updated", order: updatedOrder });
    } catch (error) {
        console.error("Update Order Status Error:", error);
        return res.status(500).json({ error: error.message || "Server Error" });
    }
});

// START THE EXPRESS SERVER
app.listen(PORT, () =>
    console.log(`EXPRESS Server Started at Port No: ${PORT}`)
);
