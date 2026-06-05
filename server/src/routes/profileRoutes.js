const express = require('express');
const multer = require('multer');
const {
  updateProfile,
  uploadProfileImage,
  fetchUserById,
  fetchDepartments,
  fetchMentorReviews,
  deleteProfileImage,
  fetchLastLogin
} = require('../controllers/profileController');
const { protect } = require('../middlewares/authMiddleware');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.get('/departments', protect, fetchDepartments);
router.put('/:userId', protect, updateProfile);
router.post('/:userId/image', protect, upload.single('image'), uploadProfileImage);
router.delete('/:userId/image', protect, deleteProfileImage);
router.get('/:userId', protect, fetchUserById);
router.get('/:userId/reviews', protect, fetchMentorReviews);
router.get('/:userId/last-login', protect, fetchLastLogin);

module.exports = router;
