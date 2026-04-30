const express = require('express');

const { bookings, dashboard, hosts, incomeSummary, users, venues } = require('../controllers/adminController');
const { protect, requireRoles } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(protect, requireRoles('VENUEHUB_ADMIN'));

router.get('/dashboard', dashboard);
router.get('/users', users);
router.get('/hosts', hosts);
router.get('/venues', venues);
router.get('/bookings', bookings);
router.get('/income-summary', incomeSummary);

module.exports = router;
