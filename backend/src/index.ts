import express from 'express';
import cors from 'cors';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Consultation from './models/Consultation.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.post('/api/consultants', async (req, res) => {
  try {
    const { firstName, lastName, email, phoneNumber } = req.body;
    
    if (!firstName || !lastName || !email || !phoneNumber) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    const consultation = new Consultation({
      firstName,
      lastName,
      email,
      phoneNumber
    });

    await consultation.save();
    res.status(201).json({ message: 'Consultation request submitted successfully' });
  } catch (error) {
    console.error('Error saving consultation:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/consultant-app')
  .then(() => {
    console.log('Connected to MongoDB');
    app.listen(port, () => {
      console.log(`Server running on port ${port}`);
    });
  })
  .catch((error) => {
    console.error('Error connecting to MongoDB:', error);
  });
