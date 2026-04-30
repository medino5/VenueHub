const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { calculateBookingAmounts } = require('../services/paymentService');
const { toNumber } = require('../utils/formatters');

const bookingInclude = {
  customer: { select: { id: true, name: true, email: true, phone: true } },
  venue: {
    include: {
      host: { select: { id: true, name: true, email: true } },
      images: { orderBy: { sortOrder: 'asc' } }
    }
  },
  payments: true,
  receipt: true,
  review: true
};

const formatBooking = (booking) => ({
  ...booking,
  totalAmount: toNumber(booking.totalAmount),
  depositAmount: toNumber(booking.depositAmount),
  remainingBalance: toNumber(booking.remainingBalance),
  serviceFee: toNumber(booking.serviceFee),
  payments: (booking.payments || []).map((payment) => ({ ...payment, amount: toNumber(payment.amount) })),
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

const createBooking = asyncHandler(async (req, res) => {
  const { venueId, eventDate, notes } = req.body;

  if (!venueId || !eventDate) {
    throw new ApiError(400, 'Venue and event date are required.');
  }

  const venue = await prisma.venue.findUnique({ where: { id: venueId } });
  if (!venue || venue.status !== 'APPROVED') {
    throw new ApiError(404, 'Approved venue not found.');
  }

  const parsedDate = new Date(eventDate);
  if (Number.isNaN(parsedDate.getTime())) {
    throw new ApiError(400, 'Event date is invalid.');
  }

  const takenBooking = await prisma.booking.findFirst({
    where: {
      venueId,
      eventDate: parsedDate,
      status: { in: ['PENDING', 'APPROVED', 'COMPLETED'] }
    }
  });

  if (takenBooking) {
    throw new ApiError(409, 'This venue already has a booking for the selected date.');
  }

  const amounts = calculateBookingAmounts(venue.pricePerDay);
  const booking = await prisma.booking.create({
    data: {
      customerId: req.user.id,
      venueId,
      eventDate: parsedDate,
      notes,
      totalAmount: amounts.totalAmount,
      depositAmount: amounts.depositAmount,
      remainingBalance: amounts.remainingBalance,
      serviceFee: amounts.serviceFee
    },
    include: bookingInclude
  });

  res.status(201).json({
    booking: formatBooking(booking),
    paymentRules: {
      depositRequiredPercent: 50,
      serviceFeePercent: 10,
      depositRefundable: false,
      note: '50% security deposit is required and non-refundable.'
    }
  });
});

const myBookings = asyncHandler(async (req, res) => {
  const bookings = await prisma.booking.findMany({
    where: { customerId: req.user.id },
    include: bookingInclude,
    orderBy: { createdAt: 'desc' }
  });

  res.json({ bookings: bookings.map(formatBooking) });
});

const hostBookings = asyncHandler(async (req, res) => {
  const bookings = await prisma.booking.findMany({
    where: { venue: { hostId: req.user.id } },
    include: bookingInclude,
    orderBy: { createdAt: 'desc' }
  });

  res.json({ bookings: bookings.map(formatBooking) });
});

const updateBookingStatus = asyncHandler(async (req, res) => {
  const { status } = req.body;
  const nextStatus = String(status || '').toUpperCase();
  const allowed = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED'];

  if (!allowed.includes(nextStatus)) {
    throw new ApiError(400, 'Invalid booking status.');
  }

  const booking = await prisma.booking.findUnique({
    where: { id: req.params.id },
    include: { venue: true }
  });

  if (!booking) {
    throw new ApiError(404, 'Booking not found.');
  }

  if (req.user.role !== 'VENUEHUB_ADMIN' && booking.venue.hostId !== req.user.id) {
    throw new ApiError(403, 'You can only update bookings for your own venues.');
  }

  const updatedBooking = await prisma.booking.update({
    where: { id: req.params.id },
    data: { status: nextStatus },
    include: bookingInclude
  });

  res.json({ booking: formatBooking(updatedBooking) });
});

const hostIncomeSummary = asyncHandler(async (req, res) => {
  const bookings = await prisma.booking.findMany({
    where: {
      venue: { hostId: req.user.id },
      paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] }
    },
    include: { payments: true, venue: true }
  });

  const grossPaid = bookings.reduce(
    (sum, booking) => sum + booking.payments.reduce((paymentSum, payment) => paymentSum + toNumber(payment.amount), 0),
    0
  );
  const platformFees = bookings.reduce((sum, booking) => sum + toNumber(booking.serviceFee), 0);

  res.json({
    summary: {
      paidBookings: bookings.length,
      grossPaid: Number(grossPaid.toFixed(2)),
      estimatedPlatformFees: Number(platformFees.toFixed(2)),
      estimatedHostIncome: Number((grossPaid - platformFees).toFixed(2))
    }
  });
});

module.exports = {
  createBooking,
  formatBooking,
  hostBookings,
  hostIncomeSummary,
  myBookings,
  updateBookingStatus
};
