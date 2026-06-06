const express = require('express');
const router = express.Router();

const {
  createMeeting,
  getMentees,
  getMeetings,
  registerForWorkshop,
  unregisterFromWorkshop,
  deleteMeeting,
  updateMeeting,
  getMeetingDetails,
  joinMeeting,
  getWorkshopParticipants
} = require('../controllers/meetingController');
const { protect, restrictTo } = require('../middlewares/authMiddleware');

router.post('/', protect, restrictTo('mentor'), createMeeting);
router.get('/', protect, getMeetings);
router.get('/mentees', protect, restrictTo('mentor'), getMentees);
router.get('/:meetingId', protect, getMeetingDetails);
router.get('/:meetingId/participants', protect, restrictTo('mentor'), getWorkshopParticipants);
router.put('/:meetingId', protect, restrictTo('mentor'), updateMeeting);
router.delete('/:meetingId', protect, restrictTo('mentor'), deleteMeeting);
router.post('/:meetingId/register', protect, restrictTo('student'), registerForWorkshop);
router.post('/:meetingId/unregister', protect, restrictTo('student'), unregisterFromWorkshop);
router.post('/:meetingId/join', protect, joinMeeting);


module.exports = router;
