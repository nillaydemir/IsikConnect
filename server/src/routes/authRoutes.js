const express = require('express');
const router = express.Router();
const { register, login, loginUnified } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.post('/login-unified', loginUnified);

module.exports = router;
