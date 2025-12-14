import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TaskProgressScreen extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;

  const TaskProgressScreen({super.key, required this.tasks});

  @override
  State<TaskProgressScreen> createState() => _TaskProgressScreenState();
}

class _TaskProgressScreenState extends State<TaskProgressScreen> {
  String? selectedCategory;
  DateTime? selectedDate;
  final GlobalKey chartKey = GlobalKey();

  List<Map<String, dynamic>> get filteredTasks {
    return widget.tasks.where((task) {
      final categoryMatch =
          selectedCategory == null || task['category'] == selectedCategory;
      final dateMatch =
          selectedDate == null ||
          (task['createdAt'] != null &&
              (task['createdAt'] as DateTime).day == selectedDate!.day &&
              (task['createdAt'] as DateTime).month == selectedDate!.month &&
              (task['createdAt'] as DateTime).year == selectedDate!.year);
      return categoryMatch && dateMatch;
    }).toList();
  }

  void clearFilters() {
    setState(() {
      selectedCategory = null;
      selectedDate = null;
    });
  }

  Future<Uint8List?> captureChartImage() async {
    final boundary =
        chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final tasks = filteredTasks;

    final grouped = <String, Map<String, int>>{};
    for (var task in tasks) {
      final cat = task['category']?.toString() ?? 'Sin categoría';
      grouped.putIfAbsent(cat, () => {'completadas': 0, 'pendientes': 0});
      if (task['completed'] == true) {
        grouped[cat]!['completadas'] = grouped[cat]!['completadas']! + 1;
      } else {
        grouped[cat]!['pendientes'] = grouped[cat]!['pendientes']! + 1;
      }
    }

    final chartImageBytes = await captureChartImage();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Resumen de Progreso de Tareas',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total tareas: ${tasks.length}'),
          pw.Text('Completadas: ${tasks.where((t) => t['completed']).length}'),
          pw.Text('Pendientes: ${tasks.where((t) => !t['completed']).length}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Tareas por categoría:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...grouped.entries.map((entry) {
            final cat = entry.key;
            final data = entry.value;
            return pw.Text(
              '- $cat: ${data['completadas']} completadas / ${data['pendientes']} pendientes',
            );
          }),
          pw.SizedBox(height: 24),
          if (chartImageBytes != null) ...[
            pw.Text(
              'Gráfico de Progreso Visual',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Image(pw.MemoryImage(chartImageBytes), height: 300),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final tasks = filteredTasks;
    final total = tasks.length;
    final completadas = tasks.where((task) => task['completed'] == true).length;
    final pendientes = total - completadas;
    final progress = total > 0 ? completadas / total : 0.0;

    final Map<String, Map<String, int>> grouped = {};
    for (var task in tasks) {
      final cat = task['category']?.toString() ?? 'Sin categoría';
      grouped.putIfAbsent(cat, () => {'completadas': 0, 'pendientes': 0});
      if (task['completed'] == true) {
        grouped[cat]!['completadas'] = grouped[cat]!['completadas']! + 1;
      } else {
        grouped[cat]!['pendientes'] = grouped[cat]!['pendientes']! + 1;
      }
    }

    final categories = grouped.keys.toList();

    final allCategories = widget.tasks
        .map((t) => t['category']?.toString() ?? 'Sin categoría')
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Progreso de Tareas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: clearFilters,
            icon: const Icon(Icons.filter_alt_off),
            tooltip: 'Limpiar filtros',
          ),
          IconButton(
            onPressed: exportToPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar a PDF',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filtros
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    hint: const Text('Filtrar por categoría'),
                    items: allCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedCategory = value);
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  tooltip: 'Filtrar por fecha',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: total == 0
                  ? const Center(child: Text('No hay tareas con estos filtros'))
                  : ListView(
                      children: [
                        _buildProgressCard(
                          progress,
                          completadas,
                          total,
                          pendientes,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Progreso por categoría',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        Column(
                          children: categories.map((cat) {
                            final completed = grouped[cat]!['completadas']!;
                            final total =
                                completed + grouped[cat]!['pendientes']!;
                            final progress = total > 0
                                ? completed / total
                                : 0.0;

                            // Determinar color basado en el progreso
                            Color progressColor;
                            if (progress < 0.33) {
                              progressColor = Colors.red;
                            } else if (progress < 0.66) {
                              progressColor = Colors.orange;
                            } else {
                              progressColor = Colors.green;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 12,
                                    backgroundColor: Colors.grey[300],
                                    color: progressColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}% completado '
                                    '($completed de $total)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    double progress,
    int completed,
    int total,
    int pending,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Progreso general',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    backgroundColor: Colors.grey[300],
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(value * 100).toStringAsFixed(0)}% completado',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusCard(
                  Icons.check_circle,
                  'Completadas',
                  completed,
                  Colors.green,
                ),
                _buildStatusCard(
                  Icons.pending,
                  'Pendientes',
                  pending,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }
}
