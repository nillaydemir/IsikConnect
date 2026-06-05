const express = require('express');
const router = express.Router();
const multer = require('multer');
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

const { registerStudent, loginStudent, rateMentor } = require('../controllers/studentController');
const { protect, restrictTo } = require('../middlewares/authMiddleware');

router.post('/register', upload.single('file'), registerStudent);
router.post('/login', loginStudent);
router.post('/rate-mentor', protect, restrictTo('student'), rateMentor);

module.exports = router;
