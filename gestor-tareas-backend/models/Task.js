const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  title: String,
  description: String,
  completed: { type: Boolean, default: false },
  category: String, 
  prioridad: String,
  startDate: Date,
  endDate: Date,
  reminder: Date,
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  createdAt: { type: Date, default: Date.now }
}, {
  collection: 'TareasDiarias'
});

module.exports = mongoose.model('Task', taskSchema);
