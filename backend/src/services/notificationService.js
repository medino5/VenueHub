const prisma = require('../config/prisma');

const createNotification = async ({ userId, title, message, type, metadata }) => {
  if (!userId || !title || !message) return null;

  return prisma.notification.create({
    data: {
      userId,
      title,
      message,
      type: type || 'GENERAL',
      metadata: metadata || undefined
    }
  });
};

module.exports = {
  createNotification
};
