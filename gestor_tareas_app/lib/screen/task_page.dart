// ignore_for_file: use_build_context_synchronously, sort_child_properties_last, avoid_print, no_leading_underscores_for_local_identifiers, curly_braces_in_flow_control_structures, prefer_final_fields, depend_on_referenced_packages

import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:gestor_tareas_app/screen/task_progress_screen.dart';
import 'package:gestor_tareas_app/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TaskPage extends StatefulWidget {
  final AuthService authService;

  const TaskPage({required this.authService, super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<Map<String, dynamic>> tasks = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  List<String> _categories = ['Todas'];

  bool _showCompletedOnly = false;
  bool _sortAsc = true;

  get selectedPriority => null;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _fetchTasks(); // ← Carga eventos desde el backend
  }

  Future<void> _fetchTasks() async {
    final token = await widget.authService.getToken();
    final response = await http.get(
      Uri.parse('http://localhost:5000/api/tasks'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        tasks.clear();
        _events.clear();

        for (var task in data) {
          final parsedTask = Map<String, dynamic>.from(task);

          // Agrupa por fecha de inicio
          if (parsedTask['startDate'] != null) {
            final start = DateTime.parse(parsedTask['startDate']).toLocal();
            final dateKey = DateTime(start.year, start.month, start.day);

            _events.putIfAbsent(dateKey, () => []);
            _events[dateKey]!.add(parsedTask);
          }

          tasks.add(parsedTask);
        }
      });
    } else {
      print('Error al cargar tareas: ${response.body}');
    }
  }

  Future<void> _updateTask(
    String id,
    String title,
    String description,
    DateTime? startDate,
    DateTime? endDate,
    String category,
    String prioridad,
  ) async {
    final token = await widget.authService.getToken();

    final response = await http.put(
      Uri.parse('http://localhost:5000/api/tasks/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'category': category,
        'prioridad': prioridad,
      }),
    );

    if (response.statusCode == 200) {
      final updatedTask = jsonDecode(response.body);

      setState(() {
        // Actualiza la lista principal
        final index = tasks.indexWhere((task) => task['_id'] == id);
        if (index != -1) {
          tasks[index] = Map<String, dynamic>.from(updatedTask);
        }

        // Actualiza el mapa de eventos
        final start = DateTime.parse(updatedTask['startDate']).toLocal();
        final dateKey = DateTime(start.year, start.month, start.day);

        if (!_events.containsKey(dateKey)) {
          _events[dateKey] = [];
        }
        _events[dateKey]!.add(Map<String, dynamic>.from(updatedTask));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea actualizada con éxito')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar la tarea')),
      );
    }
  }

  Future<void> _deleteTask(String id) async {
    final token = await widget.authService.getToken();

    final response = await http.delete(
      Uri.parse('http://localhost:5000/api/tasks/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        // 1. Elimina de la lista principal
        tasks.removeWhere((task) => task['_id'] == id);

        // 2. Elimina de la lista de eventos
        _events.forEach((date, taskList) {
          taskList.removeWhere((task) => task['_id'] == id);
        });

        // 3. Limpia días vacíos del mapa de eventos
        _events.removeWhere((key, value) => value.isEmpty);
      });

      await _fetchTasks();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tarea eliminada')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar la tarea')),
      );
    }
  }

  Future<void> _toggleCompleted(String id, bool currentStatus) async {
    final token = await widget.authService.getToken();

    final response = await http.put(
      Uri.parse('http://localhost:5000/api/tasks/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'completed': !currentStatus}),
    );

    if (response.statusCode == 200) {
      setState(() {
        final taskIndex = tasks.indexWhere((task) => task['_id'] == id);
        if (taskIndex != -1) {
          tasks[taskIndex]['completed'] = !currentStatus;
        }

        _events.forEach((date, taskList) {
          _events[date] = taskList.map((task) {
            if (task['_id'] == id) {
              task['completed'] = !currentStatus;
            }
            return task;
          }).toList();
        });
      });

      // Reproducesonido según el estado
      final player = AudioPlayer();
      final assetPath = !currentStatus
          ? 'assets/sounds/success.mp3'
          : 'assets/sounds/uncheck.mp3';
      await player.play(AssetSource(assetPath));

      await _fetchTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cambiar el estado de la tarea')),
      );
    }
  }

  Future<void> _addTaskConFechas(
    String title,
    String description,
    String category,
    String prioridad,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final token = await widget.authService.getToken();

    final response = await http.post(
      Uri.parse('http://localhost:5000/api/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'prioridad': prioridad,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      }),
    );

    if (response.statusCode == 201) {
      final newTask = jsonDecode(response.body);
      final start = DateTime.parse(newTask['startDate']).toLocal();
      final eventDate = DateTime(start.year, start.month, start.day);

      setState(() {
        tasks.add(Map<String, dynamic>.from(newTask));

        if (_events[eventDate] == null) {
          _events[eventDate] = [];
        }
        _events[eventDate]!.add(Map<String, dynamic>.from(newTask));

        final cat = newTask['category']?.toString() ?? 'Sin categoría';
        if (!_categories.contains(cat)) {
          _categories.add(cat);
        }
      });

      print('Tarea creada: ${response.body}');

      await _fetchTasks();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tarea creada con éxito')));
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String selectedCategory = 'Sin categoría';
    String selectedPriority = "Sin prioridad";

    final List<String> categoriasDisponibles = [
      'Trabajo',
      'Personal',
      'Estudio',
      'Salud',
      'Caminar',
      'Sin categoría',
    ];

    final List<String> seleccionarPrioridad = ["1", "2", "3"];

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.edit_calendar, color: Colors.teal),
                SizedBox(width: 8),
                Text('Nueva Tarea'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categoriasDisponibles
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: InputDecoration(
                      labelText: 'Prioridad',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: seleccionarPrioridad
                        .map(
                          (pri) => DropdownMenuItem<String>(
                            value: pri,
                            child: Text(pri),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedPriority = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            startDate == null
                                ? 'Fecha Inicio'
                                : '${startDate!.toLocal()}'.split(' ')[0],
                          ),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setModalState(() => startDate = pickedDate);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            startTime == null
                                ? 'Hora Inicio'
                                : startTime!.format(context),
                          ),
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setModalState(() => startTime = pickedTime);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            endDate == null
                                ? 'Fecha Fin'
                                : '${endDate!.toLocal()}'.split(' ')[0],
                          ),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setModalState(() => endDate = pickedDate);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            endTime == null
                                ? 'Hora Fin'
                                : endTime!.format(context),
                          ),
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setModalState(() => endTime = pickedTime);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  Navigator.pop(context);
                  titleController.dispose();
                  descriptionController.dispose();
                },
                label: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: () {
                  if (titleController.text.isEmpty ||
                      startDate == null ||
                      endDate == null ||
                      startTime == null ||
                      endTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor completa todos los campos'),
                      ),
                    );
                    return;
                  }

                  final startDateTime = DateTime(
                    startDate!.year,
                    startDate!.month,
                    startDate!.day,
                    startTime!.hour,
                    startTime!.minute,
                  ).toUtc();

                  final endDateTime = DateTime(
                    endDate!.year,
                    endDate!.month,
                    endDate!.day,
                    endTime!.hour,
                    endTime!.minute,
                  ).toUtc();

                  if (endDateTime.isBefore(startDateTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La fecha de fin no puede ser antes que la de inicio',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  _addTaskConFechas(
                    titleController.text,
                    descriptionController.text,
                    selectedCategory,
                    selectedPriority,
                    startDateTime,
                    endDateTime,
                  );

                  titleController.dispose();
                  descriptionController.dispose();
                },
                label: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final titleController = TextEditingController(text: task['title']);
    final descriptionController = TextEditingController(
      text: task['description'],
    );

    DateTime? selectedStartDate = task['startDate'] != null
        ? DateTime.parse(task['startDate']).toLocal()
        : null;
    DateTime? selectedEndDate = task['endDate'] != null
        ? DateTime.parse(task['endDate']).toLocal()
        : null;

    String selectedCategory = task['category']?.toString() ?? 'Sin categoría';
    String selectedPriority = task['prioridad']?.toString() ?? 'Sin prioridad';

    final dateFormat = DateFormat('yyyy-MM-dd – HH:mm');

    Future<void> _pickDateTime({required bool isStart}) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

      if (pickedDate != null) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime != null) {
          final fullDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

          if (isStart) {
            selectedStartDate = fullDateTime;
          } else {
            selectedEndDate = fullDateTime;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar Tarea'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items:
                    [
                      'Trabajo',
                      'Personal',
                      'Estudio',
                      'Salud',
                      'Caminar',
                      'Sin categoría',
                    ].map((categoria) {
                      return DropdownMenuItem(
                        value: categoria,
                        child: Text(categoria),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: const InputDecoration(labelText: 'Prioridad'),
                items: ["1", "2", "3"].map((prioridad) {
                  return DropdownMenuItem(
                    value: prioridad,
                    child: Text(prioridad),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedPriority = value;
                  }
                },
              ),
              ListTile(
                title: const Text('Fecha y hora de inicio'),
                subtitle: Text(
                  selectedStartDate != null
                      ? dateFormat.format(selectedStartDate!)
                      : 'No seleccionada',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDateTime(isStart: true),
                ),
              ),
              ListTile(
                title: const Text('Fecha y hora de fin'),
                subtitle: Text(
                  selectedEndDate != null
                      ? dateFormat.format(selectedEndDate!)
                      : 'No seleccionada',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDateTime(isStart: false),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              titleController.dispose();
              descriptionController.dispose();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateTask(
                task['_id'],
                titleController.text,
                descriptionController.text,
                selectedStartDate,
                selectedEndDate,
                selectedCategory,
                selectedPriority,
              );
              titleController.dispose();
              descriptionController.dispose();
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Editar perfil',
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (context, animation, _, __) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: const Color(0xFF99E5E2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Editar perfil',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: usernameController,
                      style: GoogleFonts.poppins(color: Colors.black87),
                      decoration: _inputDecoration(
                        label: 'Nombre de usuario',
                        icon: Icons.person,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Este campo es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      style: GoogleFonts.poppins(color: Colors.black87),
                      decoration: _inputDecoration(
                        label: 'Correo electrónico',
                        icon: Icons.email,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Este campo es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: GoogleFonts.poppins(color: Colors.black87),
                      decoration: _inputDecoration(
                        label: 'Nueva contraseña',
                        icon: Icons.lock,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Este campo es obligatorio'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                label: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Perfil actualizado (no implementado aún)',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: Text(
                  'Guardar',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.teal),
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Tareas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calendar_today), text: "Por fecha"),
              Tab(icon: Icon(Icons.list), text: "Todas"),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.teal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.task_alt, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'Gestor de Tareas',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Editar Perfil'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditProfileDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Ver tareas'),
                onTap: () {
                  Navigator.pop(context);
                  DefaultTabController.of(context).animateTo(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Progreso de tareas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskProgressScreen(tasks: tasks),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () async {
                  await widget.authService.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildCalendarView(), _buildAllTasksView()],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddTaskDialog,
          child: const Icon(Icons.add),
          backgroundColor: Colors.teal,
          tooltip: 'Agregar nueva tarea',
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    final Map<String, Color> _categoryColors = {
      'Trabajo': Colors.red,
      'Personal': Colors.green,
      'Estudio': Colors.purple,
      'Salud': Colors.orange,
      'Caminar': Colors.blue,
      'Sin categoría': Colors.grey,
    };

    return Stack(
      children: [
        tasks.isEmpty
            ? const Center(child: Text('No hay tareas todavía'))
            : Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime(2020),
                        lastDay: DateTime(2100),
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        eventLoader: (day) {
                          return _events[DateTime(
                                day.year,
                                day.month,
                                day.day,
                              )] ??
                              [];
                        },
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return const SizedBox.shrink();

                            final incompletas = events
                                .where(
                                  (task) =>
                                      task is Map && task['completed'] != true,
                                )
                                .toList();
                            final completadas = events
                                .where(
                                  (task) =>
                                      task is Map && task['completed'] == true,
                                )
                                .toList();

                            if (incompletas.isEmpty && completadas.isNotEmpty) {
                              return Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              );
                            }

                            if (incompletas.isNotEmpty) {
                              final tooltipText = events
                                  .map(
                                    (e) => e is Map
                                        ? e['title']?.toString() ?? ''
                                        : '',
                                  )
                                  .join('\n');

                              return Tooltip(
                                message: tooltipText,
                                preferBelow: false,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: incompletas.take(3).map<Widget>((
                                    task,
                                  ) {
                                    if (task is! Map<String, dynamic>)
                                      return const SizedBox.shrink();

                                    final category =
                                        task['category']?.toString() ??
                                        'Sin categoría';
                                    final color =
                                        _categoryColors[category] ??
                                        Colors.grey;

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children:
                          (_events[DateTime(
                                    _selectedDay?.year ?? _focusedDay.year,
                                    _selectedDay?.month ?? _focusedDay.month,
                                    _selectedDay?.day ?? _focusedDay.day,
                                  )] ??
                                  [])
                              .map((task) => _buildTaskCard(task))
                              .toList(),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildAllTasksView() {
    final filteredTasks = tasks.where((task) {
      final title = task['title']?.toString().toLowerCase() ?? '';
      final matchesCategory =
          _selectedCategory == 'Todas' ||
          (task['category']?.toString() ?? '') == _selectedCategory;
      final matchesSearch = title.contains(_searchQuery.toLowerCase());

      final isCompleted = task['isCompleted'] == true;
      final matchesCompleted = !_showCompletedOnly || isCompleted;

      return matchesCategory && matchesSearch && matchesCompleted;
    }).toList();

    filteredTasks.sort((a, b) {
      final dateA = DateTime.tryParse(a['startDate'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['startDate'] ?? '') ?? DateTime.now();
      return _sortAsc ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar tarea...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Solo completadas'),
                      Switch(
                        value: _showCompletedOnly,
                        onChanged: (value) {
                          setState(() {
                            _showCompletedOnly = value;
                          });
                        },
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _sortAsc = !_sortAsc;
                      });
                    },
                    icon: Icon(
                      _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                      semanticLabel: 'Ordenar por fecha',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredTasks.isEmpty
              ? const Center(child: Text('No hay tareas para mostrar'))
              : ListView.builder(
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(filteredTasks[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final completed = task['completed'] == true;

    Color _colorPorCategoria(String categoria) {
      switch (categoria) {
        case 'Trabajo':
          return Colors.blueAccent;
        case 'Personal':
          return Colors.orange;
        case 'Estudio':
          return Colors.purple;
        case 'Salud':
          return Colors.green;
        case 'Caminar':
          return Colors.brown;
        default:
          return Colors.grey;
      }
    }

    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: Checkbox(
            value: completed,
            onChanged: (val) => _toggleCompleted(task['_id'], completed),
            activeColor: Colors.teal,
          ),
          title: Text(
            task['title'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task['description']),
              if (task['category'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Chip(
                    label: Text(task['category']),
                    backgroundColor: _colorPorCategoria(task['category']),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              if (task['startDate'] != null)
                Text("📅 ${task['startDate'].split('T')[0]}"),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditTaskDialog(task),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteTask(task['_id']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
