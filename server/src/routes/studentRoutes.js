const express = require('express');
const router = express.Router();
const multer = require('multer');
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

const { registerStudent, loginStudent } = require('../controllers/studentController');

router.post('/register', upload.single('file'), registerStudent);
router.post('/login', loginStudent);

module.exports = router;
