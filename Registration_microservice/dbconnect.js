// STEP-1 : IMPORT MONGOOSE PACKAGE
const mongoose = require('mongoose');

// Database Connection URL
const uri = process.env.MONGO_URI || "mongodb+srv://2025340choup_db_user:yuth1407@cluster0.5lt6slh.mongodb.net/cloudmongo1?appName=Cluster0";

const clientOptions = { serverApi: { version: '1', strict: true, deprecationErrors: true } };

async function run() {
  try {
    await mongoose.connect(uri, clientOptions);
    await mongoose.connection.db.admin().command({ ping: 1 });
    console.log("Pinged your deployment. You successfully connected to MongoDB!");
  } catch (err) {
    console.error("MongoDB connection error in Registration:", err.message);
  }
}
run().catch(console.dir);

module.exports = mongoose;
