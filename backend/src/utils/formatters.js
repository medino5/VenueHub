const toNumber = (value) => Number(value || 0);

const publicUser = (user) => {
  if (!user) return null;

  const { password, ...safeUser } = user;
  return safeUser;
};

const normalizeRole = (role) => {
  const value = String(role || 'customer').toUpperCase();
  if (value === 'VENUEHUB_ADMIN') return 'VENUEHUB_ADMIN';
  if (value === 'HOST') return 'HOST';
  return 'CUSTOMER';
};

const normalizePaymentMethod = (method) => {
  const value = String(method || '').toUpperCase();
  const allowed = ['VISA', 'MASTERCARD', 'PAYPAL', 'GCASH', 'MAYA', 'EWALLET'];
  return allowed.includes(value) ? value : 'EWALLET';
};

module.exports = {
  normalizePaymentMethod,
  normalizeRole,
  publicUser,
  toNumber
};
