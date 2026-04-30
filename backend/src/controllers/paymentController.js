const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { simulatePayment } = require('../services/paymentService');
const { formatBooking } = require('./bookingController');
const { toNumber } = require('../utils/formatters');

const simulate = asyncHandler(async (req, res) => {
  const { bookingId, method, paymentType } = req.body;

  if (!bookingId || !method) {
    throw new ApiError(400, 'Booking and payment method are required.');
  }

  const result = await simulatePayment({
    bookingId,
    method,
    paymentType,
    customerId: req.user.role === 'CUSTOMER' ? req.user.id : null
  });

  res.status(201).json({
    message: 'Demo payment approved.',
    ...result,
    booking: formatBooking(result.booking)
  });
});

const getPaymentsForBooking = asyncHandler(async (req, res) => {
  const booking = await prisma.booking.findUnique({
    where: { id: req.params.bookingId },
    include: {
      venue: true,
      payments: { orderBy: { createdAt: 'desc' } },
      receipt: true
    }
  });

  if (!booking) {
    throw new ApiError(404, 'Booking not found.');
  }

  const isOwner = booking.customerId === req.user.id;
  const isHost = booking.venue.hostId === req.user.id;
  const isAdmin = req.user.role === 'VENUEHUB_ADMIN';

  if (!isOwner && !isHost && !isAdmin) {
    throw new ApiError(403, 'You cannot view payments for this booking.');
  }

  res.json({
    payments: booking.payments.map((payment) => ({ ...payment, amount: toNumber(payment.amount) })),
    receipt: booking.receipt
      ? {
          ...booking.receipt,
          subtotal: toNumber(booking.receipt.subtotal),
          depositPaid: toNumber(booking.receipt.depositPaid),
          remainingBalance: toNumber(booking.receipt.remainingBalance),
          serviceFee: toNumber(booking.receipt.serviceFee),
          totalPaid: toNumber(booking.receipt.totalPaid)
        }
      : null
  });
});

module.exports = {
  getPaymentsForBooking,
  simulate
};
