const express = require('express');

const { listNotifications, markNotificationsRead } = require('../controllers/notificationController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', protect, listNotifications);
router.put('/read', protect, markNotificationsRead);

module.exports = router;
