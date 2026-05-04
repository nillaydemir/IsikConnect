const express = require('express');
const multer = require('multer');
const { updateProfile, uploadProfileImage } = require('../controllers/profileController');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.put('/:userId', updateProfile);
router.post('/:userId/image', upload.single('image'), uploadProfileImage);

module.exports = router;
