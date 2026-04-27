const express = require('express');
const router = express.Router();
const multer = require('multer');
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

const { registerMentor, loginMentor, uploadDoc } = require('../controllers/mentorController');

router.post('/register', upload.single('file'), registerMentor);
router.post('/login', loginMentor);
router.post('/upload-doc', upload.single('document'), uploadDoc);

module.exports = router;
