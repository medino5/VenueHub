const nodemailer = require('nodemailer');

const { toNumber } = require('../utils/formatters');

const cleanEnv = (value) => String(value || '').trim();
const cleanSecret = (value) => cleanEnv(value).replace(/\s+/g, '');

const hasSmtpConfig = () => Boolean(cleanEnv(process.env.SMTP_HOST) && cleanEnv(process.env.SMTP_USER) && cleanSecret(process.env.SMTP_PASS));
const hasResendConfig = () => Boolean(process.env.RESEND_API_KEY);
const fromAddress = () => cleanEnv(process.env.SMTP_FROM || process.env.EMAIL_FROM) || 'VenueHub <no-reply@venuehub.demo>';
const smtpTimeoutMs = () => Number(process.env.SMTP_TIMEOUT_MS || 10000);

const isEmailConfigured = () => hasSmtpConfig() || hasResendConfig();

const transporter = () => {
  if (!hasSmtpConfig()) return null;

  return nodemailer.createTransport({
    host: cleanEnv(process.env.SMTP_HOST),
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false') === 'true',
    connectionTimeout: smtpTimeoutMs(),
    greetingTimeout: smtpTimeoutMs(),
    socketTimeout: smtpTimeoutMs(),
    auth: {
      user: cleanEnv(process.env.SMTP_USER),
      pass: cleanSecret(process.env.SMTP_PASS)
    }
  });
};

const sendMail = async ({ to, subject, html, text }) => {
  if (hasResendConfig()) {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: fromAddress(),
        to: [to],
        subject,
        html,
        text
      })
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Resend email failed: ${detail}`);
    }

    return response.json();
  }

  const mailer = transporter();

  if (!mailer) {
    throw new Error('Email is not configured. Add SMTP_* variables or RESEND_API_KEY in Render.');
  }

  try {
    return await mailer.sendMail({
      from: fromAddress(),
      to,
      subject,
      html,
      text
    });
  } catch (error) {
    if (error.code === 'EAUTH') {
      throw new Error('Email login failed. Check SMTP_USER and the Gmail app password in SMTP_PASS.');
    }
    if (['ECONNECTION', 'ETIMEDOUT', 'ESOCKET'].includes(error.code)) {
      throw new Error('Email server did not respond. Check SMTP_HOST, SMTP_PORT, SMTP_SECURE, and network access.');
    }
    throw error;
  }
};

const sendPasswordResetEmail = async ({ user, resetUrl, token }) => {
  return sendMail({
    to: user.email,
    subject: 'Reset your VenueHub password',
    text: `Reset your VenueHub password here: ${resetUrl}\n\nReset code: ${token}`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#05264D">
        <h2>Reset your VenueHub password</h2>
        <p>Hello ${user.name},</p>
        <p>Use the secure link below to set a new password. This link expires in 30 minutes.</p>
        <p><a href="${resetUrl}" style="background:#05264D;color:white;padding:12px 18px;border-radius:10px;text-decoration:none">Reset password</a></p>
        <p style="color:#52616f">If the button does not open, copy this link: ${resetUrl}</p>
        <p style="color:#52616f">For in-app reset, use this code: <strong>${token}</strong></p>
      </div>
    `
  });
};

const sendReceiptEmail = async ({ booking, receipt }) => {
  const customer = booking.customer;
  const venue = booking.venue;

  return sendMail({
    to: customer.email,
    subject: `VenueHub receipt ${receipt.receiptNumber}`,
    text: `VenueHub receipt ${receipt.receiptNumber}
Customer: ${customer.name}
Venue: ${venue.name}
Booking date: ${new Date(booking.eventDate).toLocaleString()}
Guests: ${venue.capacity}
Total cost: PHP ${toNumber(booking.totalAmount).toLocaleString()}
Payment status: ${booking.paymentStatus}
Thank you for booking with VenueHub.`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;color:#05264D;border:1px solid #E6EDF5;border-radius:18px;padding:24px">
        <h2 style="margin-top:0">VenueHub Receipt</h2>
        <p style="color:#52616f">Receipt No. ${receipt.receiptNumber}</p>
        <table style="width:100%;border-collapse:collapse">
          <tr><td style="padding:8px 0;color:#52616f">Customer</td><td style="text-align:right;font-weight:700">${customer.name}</td></tr>
          <tr><td style="padding:8px 0;color:#52616f">Venue</td><td style="text-align:right;font-weight:700">${venue.name}</td></tr>
          <tr><td style="padding:8px 0;color:#52616f">Booking date</td><td style="text-align:right;font-weight:700">${new Date(booking.eventDate).toLocaleString()}</td></tr>
          <tr><td style="padding:8px 0;color:#52616f">Guests</td><td style="text-align:right;font-weight:700">${venue.capacity}</td></tr>
          <tr><td style="padding:8px 0;color:#52616f">Total cost</td><td style="text-align:right;font-weight:700">PHP ${toNumber(booking.totalAmount).toLocaleString()}</td></tr>
          <tr><td style="padding:8px 0;color:#52616f">Payment status</td><td style="text-align:right;font-weight:700">${booking.paymentStatus}</td></tr>
        </table>
        <p style="margin-top:22px">Thank you for booking with VenueHub. Please keep this receipt for your event records.</p>
      </div>
    `
  });
};

module.exports = {
  isEmailConfigured,
  sendPasswordResetEmail,
  sendReceiptEmail
};
