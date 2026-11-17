const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
require('dotenv').config();

const app = express();
app.use(express.json());

const JWT_SECRETE = process.env.JWT_SECRETE || "347186591486#^%%ABCF*##GHE";
const MONGO_URI = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0"; 
const PORT = process.env.PORT || 5002;

mongoose.connect(MONGO_URI)
  .then(() => console.log('Authentication Service Connected to MongoDB Atlas'))
  .catch(err => console.error('MongoDB connection error:', err));

const userSchema = new mongoose.Schema({
    emailid: { type: String, required: true },
    pass: { type: String, required: true }, 
    role: { type: String, required: true }
});

const User = mongoose.model('User', userSchema, 'members');

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Login Service' }));

app.post("/login", async (req, res) => {
    const emailid = req.body.emailid || req.body.email;
    const password = req.body.password || req.body.pass;
    const role = req.body.role;

    if (!emailid || !password) {
        return res.status(400).send("Invalid credentials or role");
    }

    try {
        const user = await User.findOne({ emailid: emailid });

        if (!user) {
            console.log(`[LOGIN FAILED] Email: "${emailid}" - Reason: User not found in database.`);
            return res.status(400).send("Invalid credentials or role"); 
        }

        // Check if the provided role matches the database role
        if (role && user.role !== role) {
            console.log(`[LOGIN FAILED] Email: "${emailid}" - Reason: Role mismatch (Provided: "${role}", Expected: "${user.role}").`);
            return res.status(400).send("Invalid credentials or role");
        }

        const isPasswordValid = await bcrypt.compare(password, user.pass);

        if (!isPasswordValid) {
            console.log(`[LOGIN FAILED] Email: "${emailid}" - Reason: Incorrect password.`);
            return res.status(400).send("Invalid credentials or role");
        }

        console.log(`[LOGIN SUCCESS] Email: "${emailid}" with role "${user.role}" logged in successfully.`);
        const token = jwt.sign({ emailid: user.emailid, role: user.role }, JWT_SECRETE, { expiresIn: '24h' });
        return res.json({ token });
        
    } catch (error) {
        console.error(`[LOGIN ERROR] Email: "${emailid}" - Reason: Server/Database error -`, error);
        return res.status(500).send("Internal Server Error");
    }
});

app.post("/logout", (req, res) => {
    return res.status(200).json({ message: "Logged out successfully" });
});

app.listen(PORT, () => {
    console.log(`Authentication Service Server is running on PORT NO: ${PORT}`);
});
