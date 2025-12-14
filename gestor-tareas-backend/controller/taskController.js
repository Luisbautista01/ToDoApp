const Task = require('../models/Task');

// Obtener todas las tareas del usuario autenticado
exports.getTasks = async (req, res) => {
  try {
    const tasks = await Task.find({ userId: req.user.id });
    res.json(tasks);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error al obtener tareas' });
  }
};

// Crear una nueva tarea
exports.createTask = async (req, res) => {
  try {
    const { title, description, category, startDate, endDate, reminder } = req.body;
    const task = await Task.create({
      title,
      description,
      category,
      startDate,
      endDate,
      prioridad,
      reminder,
      userId: req.user.id,
    });
    console.log('Tarea creada para el usuario:', req.user?.id);
    res.status(201).json(task);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error al crear la tarea' });
  }
};

// Actualizar una tarea
exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      title,
      description,
      completed,
      category,
      startDate,
      endDate,
      prioridad,
      reminder,
    } = req.body;

    const task = await Task.findOne({ _id: id, userId: req.user.id });

    if (!task) {
      return res.status(404).json({ message: 'Tarea no encontrada' });
    }

    task.title = title ?? task.title;
    task.description = description ?? task.description;
    task.completed = completed ?? task.completed;
    task.category = category ?? task.category;
    task.prioridad = prioridad ?? task.prioridad;
    task.startDate = startDate ?? task.startDate;
    task.endDate = endDate ?? task.endDate;
    task.reminder = reminder ?? task.reminder;

    await task.save();
    res.json(task);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error al actualizar la tarea' });
  }
};

// Eliminar una tarea
exports.deleteTask = async (req, res) => {
  try {
    await Task.findOneAndDelete({ _id: req.params.id, userId: req.user.id });
    res.json({ msg: 'Tarea eliminada' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error al eliminar la tarea' });
  }
};
