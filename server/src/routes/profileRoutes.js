const express = require('express');
const multer = require('multer');
const { updateProfile, uploadProfileImage } = require('../controllers/profileController');
const { protect } = require('../middlewares/authMiddleware');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.put('/:userId', protect, updateProfile);
router.post('/:userId/image', protect, upload.single('image'), uploadProfileImage);

module.exports = router;
