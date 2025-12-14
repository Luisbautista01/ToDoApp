const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username:       { type: String, required: true, unique: true },
  email:          { type: String, required: true, unique: true },
  password:       { type: String, required: true },
  secretQuestion: { type: String, required: true },
  secretAnswer:   { type: String, required: true },
  resetToken:     { type: String },
  resetTokenExp:  { type: Date }
});

module.exports = mongoose.model('User', userSchema);
