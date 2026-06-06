const express = require('express');
const router = express.Router();

const {
  runMatching,
  cancelMatch,
  getStudentCancelledMatchCount,
  getMentorCancelledMatchCount,
  getActiveMatch
} = require('../controllers/matchingController');
const { protect, restrictTo } = require('../middlewares/authMiddleware');

router.post('/run', protect, restrictTo('student'), runMatching);
router.post('/cancel', protect, cancelMatch);
router.get('/active', protect, restrictTo('student'), getActiveMatch);
router.get('/cancelled-count/student/:studentId', protect, getStudentCancelledMatchCount);
router.get('/cancelled-count/mentor/:mentorId', protect, getMentorCancelledMatchCount);


module.exports = router;
