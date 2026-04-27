const express = require('express');
const cors = require('cors');
const authRoutes = require('./src/routes/authRoutes');
const mentorRoutes = require('./src/routes/mentorRoutes');
const adminRoutes = require('./src/routes/adminRoutes');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/auth', authRoutes);
app.use('/mentor', mentorRoutes);
app.use('/admin', adminRoutes);

app.get('/', (req, res) => {
  res.send('IsikConnect API is running...');
});

app.use((err, req, res, next) => {
  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  res.status(statusCode).json({
    message: err.message,
    stack: process.env.NODE_ENV === 'production' ? null : err.stack,
  });
});

module.exports = app;
