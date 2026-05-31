const crypto = require('crypto');

const prisma = require('../config/prisma');
const ApiError = require('../utils/apiError');
const { normalizePaymentMethod, toNumber } = require('../utils/formatters');

const DEFAULT_SERVICE_FEE_PERCENT = 10;

const getServiceFeePercent = async () => {
  const setting = await prisma.platformSetting.upsert({
    where: { id: 'platform' },
    update: {},
    create: { id: 'platform', serviceFeePercent: DEFAULT_SERVICE_FEE_PERCENT }
  });

  return toNumber(setting.serviceFeePercent) || DEFAULT_SERVICE_FEE_PERCENT;
};

const calculateBookingAmounts = (pricePerDay, serviceFeePercent = DEFAULT_SERVICE_FEE_PERCENT) => {
  const subtotal = toNumber(pricePerDay);
  const depositAmount = Number((subtotal * 0.5).toFixed(2));
  const remainingBalance = Number((subtotal - depositAmount).toFixed(2));
  const serviceFee = Number((subtotal * (toNumber(serviceFeePercent) / 100)).toFixed(2));

  return {
    subtotal,
    totalAmount: subtotal,
    depositAmount,
    remainingBalance,
    serviceFee
  };
};

const receiptNumber = () => `VH-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;

const transactionRef = () => `SIM-${Date.now()}-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

const paidAmount = (payments = []) =>
  payments
    .filter((payment) => payment.status === 'SUCCESS')
    .reduce((sum, payment) => sum + toNumber(payment.amount), 0);

const simulatePayment = async ({ bookingId, customerId, method, paymentType = 'DEPOSIT' }) => {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      venue: true,
      payments: true,
      receipt: true
    }
  });

  if (!booking) {
    throw new ApiError(404, 'Booking not found.');
  }

  if (customerId && booking.customerId !== customerId) {
    throw new ApiError(403, 'You can only pay for your own bookings.');
  }

  if (booking.status === 'REJECTED' || booking.status === 'CANCELLED') {
    throw new ApiError(400, 'Rejected or cancelled bookings cannot be paid.');
  }

  if (booking.status === 'PENDING') {
    throw new ApiError(400, 'The host must approve this booking before payment.');
  }

  if (booking.status === 'COMPLETED') {
    throw new ApiError(400, 'Completed bookings are already closed.');
  }

  if (booking.status !== 'APPROVED') {
    throw new ApiError(400, 'Only approved bookings can be paid.');
  }

  const normalizedType = String(paymentType || 'DEPOSIT').toUpperCase();
  if (!['DEPOSIT', 'BALANCE', 'FULL'].includes(normalizedType)) {
    throw new ApiError(400, 'Invalid payment type.');
  }

  const totalAmount = toNumber(booking.totalAmount);
  const depositAmount = toNumber(booking.depositAmount);
  const existingPaid = paidAmount(booking.payments);

  if (existingPaid >= totalAmount) {
    throw new ApiError(400, 'This booking is already fully paid.');
  }

  let amount = depositAmount;
  let nextStatus = 'PARTIALLY_PAID';

  if (normalizedType === 'DEPOSIT') {
    if (existingPaid >= depositAmount) {
      throw new ApiError(400, 'The security deposit is already paid. Pay the remaining balance instead.');
    }
    amount = Math.max(depositAmount - existingPaid, 0);
  }

  if (normalizedType === 'BALANCE') {
    if (existingPaid < depositAmount) {
      throw new ApiError(400, 'Please pay the 50% security deposit before the remaining balance.');
    }
    amount = Math.max(totalAmount - existingPaid, 0);
    nextStatus = 'PAID';
  }

  if (normalizedType === 'FULL') {
    amount = Math.max(totalAmount - existingPaid, 0);
    nextStatus = 'PAID';
  }

  if (amount <= 0) {
    throw new ApiError(400, 'This booking is already fully paid.');
  }

  const normalizedMethod = normalizePaymentMethod(method);

  const result = await prisma.$transaction(async (tx) => {
    const payment = await tx.payment.create({
      data: {
        bookingId,
        amount,
        method: normalizedMethod,
        type: normalizedType === 'BALANCE' || normalizedType === 'FULL' ? normalizedType : 'DEPOSIT',
        transactionRef: transactionRef()
      }
    });

    const totalPaid = existingPaid + amount;
    const paymentStatus = totalPaid >= totalAmount ? 'PAID' : nextStatus;

    const updatedBooking = await tx.booking.update({
      where: { id: bookingId },
      data: { paymentStatus },
      include: {
        customer: { select: { id: true, name: true, email: true, phone: true } },
        venue: { include: { host: { select: { id: true, name: true, email: true } } } },
        payments: true
      }
    });

    const receipt = await tx.receipt.upsert({
      where: { bookingId },
      update: {
        depositPaid: Math.min(totalPaid, depositAmount),
        remainingBalance: Math.max(totalAmount - totalPaid, 0),
        totalPaid,
        paymentMethod: normalizedMethod
      },
      create: {
        bookingId,
        receiptNumber: receiptNumber(),
        subtotal: totalAmount,
        depositPaid: Math.min(totalPaid, depositAmount),
        remainingBalance: Math.max(totalAmount - totalPaid, 0),
        serviceFee: toNumber(booking.serviceFee),
        totalPaid,
        paymentMethod: normalizedMethod,
        securityNote: '50% security deposit is non-refundable. Remaining balance is due before or on event day.'
      }
    });

    const paymentLabel =
      paymentStatus === 'PAID' ? 'Full payment completed' : 'Security deposit paid';

    await tx.notification.createMany({
      data: [
        {
          userId: updatedBooking.customerId,
          title: paymentLabel,
          message: `${updatedBooking.venue.name} payment was recorded via ${normalizedMethod}.`,
          type: 'PAYMENT_UPDATE',
          metadata: { bookingId, venueId: updatedBooking.venueId, paymentId: payment.id, paymentStatus }
        },
        {
          userId: updatedBooking.venue.hostId,
          title: 'Booking payment update',
          message: `${updatedBooking.customer.name} paid ${payment.type.toLowerCase()} for ${updatedBooking.venue.name}.`,
          type: 'PAYMENT_UPDATE',
          metadata: { bookingId, venueId: updatedBooking.venueId, paymentId: payment.id, paymentStatus }
        }
      ]
    });

    return { booking: updatedBooking, payment, receipt };
  });

  return result;
};

module.exports = {
  calculateBookingAmounts,
  getServiceFeePercent,
  simulatePayment
};
