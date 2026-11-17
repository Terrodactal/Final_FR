const express = require('express');
const bcrypt = require('bcrypt');
var app = express();

var bodyParser = require("body-parser");
app.use(bodyParser.json());

const dbconnect = require('./dbconnect.js');
const PersonModel = require('./person_schema.js');

const PORT = process.env.PORT || 5001;

function uniqueid(min, max) {
  return Math.floor(
    Math.random() * (max - min + 1) + min
  );
}

app.get('/health', (req, res) => res.status(200).json({ status: 'UP', service: 'Registration Service' }));

// REG API
app.post('/register', async (req, res) => {
  console.log("REG API EXECUTED");
  
  try {
    const email = req.body.email || req.body.emailid;
    if (!email) {
      return res.status(400).send('Email is required');
    }

    const password = req.body.password || req.body.pass;
    if (!password) {
      return res.status(400).send('Password is required');
    }

    // Check if user with this email already exists
    const existingUser = await PersonModel.findOne({ emailid: email });
    if (existingUser) {
      return res.status(400).send('EMAIL ALREADY EXISTS IN DATABASE');
    }

    // Generate a salt and hash the password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const pobj = new PersonModel({
      id: uniqueid(1000, 9999),
      name: req.body.name,
      emailid: email,
      pass: hashedPassword,
      mobile: req.body.mobile,
      role: req.body.role || 'Worker'
    });

    // INSERT/SAVE THE RECORD/DOCUMENT
    await pobj.save();
    return res.status(200).send('DOCUMENT INSERTED IN MONGODB DATABASE');

  } catch (error) {
    console.error("Error during registration:", error);
    return res.status(500).send({ message: error.message || 'Internal server error during registration' });
  }
});

app.listen(PORT, () => console.log(`EXPRESS Server Started at Port No: ${PORT}`));
