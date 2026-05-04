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

  const normalizedType = String(paymentType || 'DEPOSIT').toUpperCase();
  const existingPaid = booking.payments
    .filter((payment) => payment.status === 'SUCCESS')
    .reduce((sum, payment) => sum + toNumber(payment.amount), 0);

  let amount = toNumber(booking.depositAmount);
  let nextStatus = 'PARTIALLY_PAID';

  if (normalizedType === 'BALANCE') {
    amount = Math.max(toNumber(booking.totalAmount) - existingPaid, 0);
    nextStatus = 'PAID';
  }

  if (normalizedType === 'FULL') {
    amount = Math.max(toNumber(booking.totalAmount) - existingPaid, 0);
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
    const paymentStatus = totalPaid >= toNumber(booking.totalAmount) ? 'PAID' : nextStatus;

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
        depositPaid: Math.min(totalPaid, toNumber(booking.depositAmount)),
        remainingBalance: Math.max(toNumber(booking.totalAmount) - totalPaid, 0),
        totalPaid,
        paymentMethod: normalizedMethod
      },
      create: {
        bookingId,
        receiptNumber: receiptNumber(),
        subtotal: toNumber(booking.totalAmount),
        depositPaid: Math.min(totalPaid, toNumber(booking.depositAmount)),
        remainingBalance: Math.max(toNumber(booking.totalAmount) - totalPaid, 0),
        serviceFee: toNumber(booking.serviceFee),
        totalPaid,
        paymentMethod: normalizedMethod,
        securityNote: '50% security deposit is non-refundable. Remaining balance is due before or on event day.'
      }
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
