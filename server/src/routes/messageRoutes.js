const express = require('express');
const router = express.Router();
const {
  fetchConversations,
  fetchChat,
  sendMessage,
  markAsRead,
  deleteChat,
  checkConnectionStatus
} = require('../controllers/messageController');
const { protect } = require('../middlewares/authMiddleware');

router.get('/conversations', protect, fetchConversations);
router.get('/chat/:targetUserId', protect, fetchChat);
router.post('/send', protect, sendMessage);
router.post('/mark-read', protect, markAsRead);
router.post('/delete-chat', protect, deleteChat);
router.get('/connection-status/:targetUserId', protect, checkConnectionStatus);

module.exports = router;
