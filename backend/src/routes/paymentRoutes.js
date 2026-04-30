const express = require('express');

const { getPaymentsForBooking, simulate } = require('../controllers/paymentController');
const { protect, requireRoles } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/simulate', protect, requireRoles('CUSTOMER', 'VENUEHUB_ADMIN'), simulate);
router.get('/:bookingId', protect, getPaymentsForBooking);

module.exports = router;
