const User = require('../models/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const createToken = (user) => {
  return jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1d' });
};

exports.register = async (req, res) => {
  try {
    const { username, email, password, secretQuestion, secretAnswer } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) return res.status(400).json({ msg: 'Correo ya registrado' });

    const hashedPassword = await bcrypt.hash(password, 10);
    const hashedAnswer = await bcrypt.hash(secretAnswer.toLowerCase(), 10);

    const user = await User.create({
      username,
      email,
      password: hashedPassword,
      secretQuestion,
      secretAnswer: hashedAnswer
    });

    const token = createToken(user);
    res.status(201).json({ token });
  } catch (err) {
    res.status(500).json({ msg: 'Error al registrar', error: err });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ msg: 'Usuario no encontrado' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ msg: 'Contraseña incorrecta' });

    const token = createToken(user);
    res.json({ token });
  } catch (err) {
    res.status(500).json({ msg: 'Error al iniciar sesión', error: err });
  }
};

exports.getProfile = (req, res) => {
  res.json({
    name: req.user.username,
    email: req.user.email
  });
};

exports.checkUser = async (req, res) => {
  try {
    const { email, username } = req.body;
    const existingEmail = await User.findOne({ email });
    const existingUsername = await User.findOne({ username });

    if (existingEmail) return res.status(200).json({ exists: true, field: 'email', msg: 'El correo ya está registrado' });
    if (existingUsername) return res.status(200).json({ exists: true, field: 'username', msg: 'El nombre de usuario ya está en uso' });

    return res.status(200).json({ exists: false, msg: 'Usuario disponible' });
  } catch (err) {
    return res.status(500).json({ msg: 'Error al verificar usuario', error: err });
  }
};

exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ msg: 'Correo no encontrado' });

    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetUrl = `http://localhost:3000/#/reset-password/${resetToken}`;

    user.resetToken = resetToken;
    user.resetTokenExp = Date.now() + 1000 * 60 * 15;
    await user.save();

    const transporter = nodemailer.createTransport({
      host: 'sandbox.smtp.mailtrap.io',
      port: 587,
      auth: {
        user: process.env.MAILTRAP_USER,
        pass: process.env.MAILTRAP_PASS
      }
    });

    await transporter.sendMail({
      to: user.email,
      subject: 'Restablecimiento de contraseña',
     html: `
        <h2>Recuperación de contraseña</h2>
        <p>Haz clic en el siguiente enlace para restablecer tu contraseña:</p>
        <a href="${resetUrl}">${resetUrl}</a>
        <p>Este enlace expirará en 15 minutos.</p>
      `,
    });

    res.json({ msg: 'Correo de recuperación enviado' });
  } catch (err) {
    res.status(500).json({ msg: 'Error al enviar el correo', error: err });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const { token } = req.params;
    const { newPassword } = req.body;

    const user = await User.findOne({
      resetToken: token,
      resetTokenExp: { $gt: Date.now() }
    });

    if (!user) return res.status(400).json({ msg: 'Token inválido o expirado' });

    user.password = await bcrypt.hash(newPassword, 10);
    user.resetToken = undefined;
    user.resetTokenExp = undefined;

    await user.save();

    res.json({ msg: 'Contraseña restablecida con éxito' });
  } catch (err) {
    res.status(500).json({ msg: 'Error al restablecer contraseña', error: err });
  }
};

exports.secretRecovery = async (req, res) => {
  try {
    const { email, secretAnswer, newPassword } = req.body;
    console.log('Recuperando para:', email);

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ msg: 'Usuario no encontrado' });

    console.log('Respuesta ingresada:', secretAnswer);
    console.log('Respuesta guardada:', user.secretAnswer);

    const isMatch = await bcrypt.compare(secretAnswer.toLowerCase(), user.secretAnswer);
    if (!isMatch) return res.status(401).json({ msg: 'Respuesta incorrecta' });

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.password = hashedPassword;
    await user.save();

    res.json({ msg: 'Contraseña restablecida con éxito por respuesta secreta' });
  } catch (err) {
    console.error('ERROR en secretRecovery:', err);
    res.status(500).json({ msg: 'Error en recuperación', error: err.message });
  }
};



