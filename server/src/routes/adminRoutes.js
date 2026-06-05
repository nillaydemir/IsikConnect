const express = require('express');
const router = express.Router();
const {
  listPendingApplications,
  updateApplicationStatus,
  fetchUsers,
  updateUserField,
  fetchStats,
  fetchSupportTickets,
  fetchReviews,
  updateTicket,
  sendAdminMessage
} = require('../controllers/adminController');
const { protect, restrictTo } = require('../middlewares/authMiddleware');

router.get('/applications/pending', protect, restrictTo('admin'), listPendingApplications);
router.post('/applications/update', protect, restrictTo('admin'), updateApplicationStatus);

router.get('/users', protect, restrictTo('admin'), fetchUsers);
router.put('/users/:userId', protect, restrictTo('admin'), updateUserField);
router.get('/stats', protect, restrictTo('admin'), fetchStats);
router.get('/tickets', protect, restrictTo('admin'), fetchSupportTickets);
router.get('/reviews', protect, restrictTo('admin'), fetchReviews);
router.put('/tickets/:ticketId', protect, restrictTo('admin'), updateTicket);
router.post('/messages', protect, restrictTo('admin'), sendAdminMessage);

module.exports = router;
