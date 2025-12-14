const express = require('express');
const router = express.Router();
const authCtrl = require('../controller/authController');

router.post('/check-user', authCtrl.checkUser);
router.post('/register', authCtrl.register);
router.post('/login', authCtrl.login);
router.post('/forgot-password', authCtrl.forgotPassword);
router.post('/reset-password/:token', authCtrl.resetPassword);
router.post('/secret-recovery', authCtrl.secretRecovery);

module.exports = router;
