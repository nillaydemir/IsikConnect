const express = require('express');
const { deleteAccount, createSupportTicket, changePassword } = require('../controllers/accountController');
const { protect } = require('../middlewares/authMiddleware');

const router = express.Router();

router.delete('/:userId', protect, deleteAccount);
router.post('/support', protect, createSupportTicket);
router.post('/change-password', protect, changePassword);

module.exports = router;
