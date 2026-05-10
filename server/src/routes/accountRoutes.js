const express = require('express');
const { deleteAccount, createSupportTicket } = require('../controllers/accountController');
const { protect } = require('../middlewares/authMiddleware');

const router = express.Router();

router.delete('/:userId', protect, deleteAccount);
router.post('/support', protect, createSupportTicket);

module.exports = router;
