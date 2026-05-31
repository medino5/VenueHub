const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const asyncHandler = require('../utils/asyncHandler');
const { calculateBookingAmounts, getServiceFeePercent } = require('../services/paymentService');
const { createNotification } = require('../services/notificationService');
const { toNumber } = require('../utils/formatters');

const bookingInclude = {
  customer: {
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      gender: true,
      profileImageUrl: true,
      preferences: true,
      likes: true,
      dislikes: true,
      specialNotes: true
    }
  },
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

const validateStatusTransition = (booking, nextStatus) => {
  const currentStatus = booking.status;
  const paymentStatus = booking.paymentStatus;
  const finalStatuses = ['REJECTED', 'CANCELLED', 'COMPLETED'];

  if (nextStatus === currentStatus) {
    throw new ApiError(400, `Booking is already ${nextStatus.toLowerCase()}.`);
  }

  if (finalStatuses.includes(currentStatus)) {
    throw new ApiError(400, `A ${currentStatus.toLowerCase()} booking can no longer be changed.`);
  }

  if (nextStatus === 'PENDING') {
    throw new ApiError(400, 'Bookings cannot be moved back to pending.');
  }

  if (nextStatus === 'APPROVED' && currentStatus !== 'PENDING') {
    throw new ApiError(400, 'Only pending bookings can be approved.');
  }

  if (nextStatus === 'REJECTED') {
    if (currentStatus !== 'PENDING') {
      throw new ApiError(400, 'Only pending bookings can be rejected.');
    }
    if (paymentStatus !== 'UNPAID') {
      throw new ApiError(400, 'Paid bookings cannot be rejected because the security deposit is non-refundable.');
    }
  }

  if (nextStatus === 'CANCELLED' && paymentStatus !== 'UNPAID') {
    throw new ApiError(400, 'Paid bookings cannot be cancelled from this demo flow.');
  }

  if (nextStatus === 'COMPLETED') {
    if (currentStatus !== 'APPROVED') {
      throw new ApiError(400, 'Only approved bookings can be completed.');
    }
    if (paymentStatus !== 'PAID') {
      throw new ApiError(400, 'The customer must fully pay before the booking can be completed.');
    }
  }
};

const statusNotification = (booking, nextStatus) => {
  const venueName = booking.venue.name;
  const messages = {
    APPROVED: {
      title: 'Booking approved',
      message: `${venueName} was approved. You can now pay the 50% security deposit.`
    },
    REJECTED: {
      title: 'Booking rejected',
      message: `${venueName} was rejected by the host. Please choose another date or venue.`
    },
    CANCELLED: {
      title: 'Booking cancelled',
      message: `${venueName} was cancelled.`
    },
    COMPLETED: {
      title: 'Booking completed',
      message: `${venueName} was marked completed. Thank you for booking with VenueHub.`
    }
  };

  return messages[nextStatus] || {
    title: 'Booking updated',
    message: `${venueName} was updated to ${nextStatus.toLowerCase()}.`
  };
};

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

  const serviceFeePercent = await getServiceFeePercent();
  const amounts = calculateBookingAmounts(venue.pricePerDay, serviceFeePercent);
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

  await createNotification({
    userId: venue.hostId,
    title: 'New booking request',
    message: `${req.user.name} requested ${venue.name} for ${parsedDate.toLocaleDateString()}.`,
    type: 'BOOKING_REQUEST',
    metadata: { bookingId: booking.id, venueId }
  });

  res.status(201).json({
    booking: formatBooking(booking),
    paymentRules: {
      depositRequiredPercent: 50,
      serviceFeePercent,
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

  validateStatusTransition(booking, nextStatus);

  const updatedBooking = await prisma.$transaction(async (tx) => {
    const nextBooking = await tx.booking.update({
      where: { id: req.params.id },
      data: { status: nextStatus },
      include: bookingInclude
    });

    if (['APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED'].includes(nextStatus)) {
      const notification = statusNotification(nextBooking, nextStatus);
      await tx.notification.create({
        data: {
          userId: nextBooking.customerId,
          title: notification.title,
          message: notification.message,
          type: 'BOOKING_STATUS',
          metadata: { bookingId: nextBooking.id, venueId: nextBooking.venueId, status: nextStatus }
        }
      });
    }

    return nextBooking;
  });

  res.json({
    message: statusNotification(updatedBooking, nextStatus).message,
    booking: formatBooking(updatedBooking)
  });
});

const hostIncomeSummary = asyncHandler(async (req, res) => {
  const [paidBookings, allHostBookings, recentBookings, venues] = await Promise.all([
    prisma.booking.findMany({
      where: {
        venue: { hostId: req.user.id },
        paymentStatus: { in: ['PARTIALLY_PAID', 'PAID'] }
      },
      include: { payments: true, venue: true }
    }),
    prisma.booking.findMany({
      where: { venue: { hostId: req.user.id } },
      include: { payments: true, venue: true }
    }),
    prisma.booking.findMany({
      where: { venue: { hostId: req.user.id } },
      include: { venue: true },
      orderBy: { createdAt: 'desc' },
      take: 6
    }),
    prisma.venue.findMany({ where: { hostId: req.user.id } })
  ]);

  const grossPaid = paidBookings.reduce(
    (sum, booking) => sum + booking.payments.reduce((paymentSum, payment) => paymentSum + toNumber(payment.amount), 0),
    0
  );
  const platformFees = paidBookings.reduce((sum, booking) => {
    const bookingPaid = booking.payments.reduce((paymentSum, payment) => paymentSum + toNumber(payment.amount), 0);
    const ratio = toNumber(booking.totalAmount) > 0 ? Math.min(bookingPaid / toNumber(booking.totalAmount), 1) : 0;
    return sum + toNumber(booking.serviceFee) * ratio;
  }, 0);
  const outstandingBalance = allHostBookings.reduce((sum, booking) => {
    if (!['APPROVED', 'PENDING'].includes(booking.status) || booking.paymentStatus === 'PAID') return sum;
    const bookingPaid = booking.payments.reduce((paymentSum, payment) => paymentSum + toNumber(payment.amount), 0);
    return sum + Math.max(toNumber(booking.totalAmount) - bookingPaid, 0);
  }, 0);
  const approvedBookings = allHostBookings.filter((booking) => booking.status === 'APPROVED').length;
  const completedBookings = allHostBookings.filter((booking) => booking.status === 'COMPLETED').length;
  const rejectedBookings = allHostBookings.filter((booking) => booking.status === 'REJECTED').length;
  const conversionRate = allHostBookings.length
    ? Number(((approvedBookings + completedBookings) / allHostBookings.length * 100).toFixed(1))
    : 0;
  const averageBookingValue = allHostBookings.length
    ? Number((allHostBookings.reduce((sum, booking) => sum + toNumber(booking.totalAmount), 0) / allHostBookings.length).toFixed(2))
    : 0;
  const topVenueMap = new Map();
  allHostBookings.forEach((booking) => {
    const current = topVenueMap.get(booking.venueId) || {
      id: booking.venueId,
      venueName: booking.venue.name,
      bookings: 0,
      grossPaid: 0
    };
    current.bookings += 1;
    current.grossPaid += booking.payments.reduce((sum, payment) => sum + toNumber(payment.amount), 0);
    topVenueMap.set(booking.venueId, current);
  });

  res.json({
    summary: {
      paidBookings: paidBookings.length,
      totalBookings: allHostBookings.length,
      pendingBookings: allHostBookings.filter((booking) => booking.status === 'PENDING').length,
      approvedBookings,
      completedBookings,
      rejectedBookings,
      activeVenues: venues.filter((venue) => venue.status === 'APPROVED').length,
      pendingVenues: venues.filter((venue) => venue.status === 'PENDING').length,
      grossPaid: Number(grossPaid.toFixed(2)),
      estimatedPlatformFees: Number(platformFees.toFixed(2)),
      estimatedHostIncome: Number((grossPaid - platformFees).toFixed(2)),
      outstandingBalance: Number(outstandingBalance.toFixed(2)),
      averageBookingValue,
      conversionRate,
      topVenues: Array.from(topVenueMap.values())
        .sort((left, right) => right.grossPaid - left.grossPaid || right.bookings - left.bookings)
        .slice(0, 4)
        .map((venue) => ({ ...venue, grossPaid: Number(venue.grossPaid.toFixed(2)) })),
      recentActivity: recentBookings.map((booking) => ({
        id: booking.id,
        venueName: booking.venue.name,
        status: booking.status,
        paymentStatus: booking.paymentStatus,
        createdAt: booking.createdAt
      }))
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
