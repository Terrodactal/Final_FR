const express = require('express');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";
const PORT = process.env.PORT || 5007;

mongoose.connect(MONGO_URI)
  .then(() => console.log('User Profile Service Connected to MongoDB Atlas'))
  .catch(err => console.error('MongoDB connection error:', err));

const personSchema = new mongoose.Schema({
  id: { type: Number },
  name: { type: String },
  emailid: { type: String, required: true },
  pass: { type: String },
  mobile: { type: Number },
  role: { type: String }
}, { timestamps: true });

const User = mongoose.model('User', personSchema, 'members');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'User Profile Service' }));

// READ API - GET /viewprofile
app.get('/viewprofile', async (req, res) => {
  try {
    const emailid = req.body?.emailid || req.body?.email || req.query?.emailid || req.query?.email || req.headers['x-user-email'];
    if (!emailid) {
      return res.status(400).json({ message: "emailid is required to view profile" });
    }
    const user = await User.findOne({ emailid }).select('-pass');
    if (!user) {
      return res.status(404).json({ message: "User profile not found" });
    }
    return res.status(200).json({
      id: user.id,
      name: user.name,
      emailid: user.emailid,
      email: user.emailid,
      mobile: user.mobile,
      role: user.role
    });
  } catch (err) {
    console.error("View Profile Error:", err);
    return res.status(500).json({ error: "Server Error" });
  }
});

// UPDATE API - PUT /updateprofile
app.put('/updateprofile', async (req, res) => {
  try {
    const emailid = req.body?.emailid || req.body?.email || req.headers['x-user-email'];
    if (!emailid) {
      return res.status(400).json({ message: "emailid is required to update profile" });
    }

    const updateData = {};
    if (req.body.name) updateData.name = req.body.name;
    if (req.body.mobile) updateData.mobile = req.body.mobile;

    const updatedUser = await User.findOneAndUpdate(
      { emailid },
      { $set: updateData },
      { new: true }
    ).select('-pass');

    if (!updatedUser) {
      return res.status(404).json({ message: "User not found to update" });
    }

    return res.status(200).json({
      message: "Profile updated successfully",
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        emailid: updatedUser.emailid,
        mobile: updatedUser.mobile,
        role: updatedUser.role
      }
    });
  } catch (err) {
    console.error("Update Profile Error:", err);
    return res.status(500).json({ error: "Server Error" });
  }
});

app.listen(PORT, () => {
  console.log(`User Profile Service running on PORT: ${PORT}`);
});
