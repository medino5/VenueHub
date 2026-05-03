const express = require('express');

const {
  changePassword,
  forgotPassword,
  login,
  me,
  register,
  resetPassword,
  resetPasswordForm,
  resetPasswordPage
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.get('/reset-password-page', resetPasswordPage);
router.post('/reset-password-form', resetPasswordForm);
router.get('/me', protect, me);
router.put('/change-password', protect, changePassword);

module.exports = router;
