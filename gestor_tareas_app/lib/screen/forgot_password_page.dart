// ignore_for_file: file_names, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gestor_tareas_app/screen/floating_particles.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailCtrl = TextEditingController();
  final answerCtrl = TextEditingController();
  bool isLoading = false;

  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final questionCtrl = TextEditingController();

  bool showPassword = false;
  double passwordStrength = 0;

  String? selectedQuestion;
  late List<String> secretQuestions;

  @override
  void initState() {
    super.initState();
    secretQuestions = [
      'Selecciona una pregunta',
      '¿Nombre de tu primera mascota?',
      '¿Ciudad donde naciste?',
      '¿Nombre de tu mejor amigo de la infancia?',
      '¿Cuál es tu película favorita?',
      '¿Color favorito?',
    ];
    selectedQuestion = secretQuestions[0];
  }

  Future<void> sendRecoveryEmail() async {
    final email = emailCtrl.text.trim();

    if (!(email.endsWith('@gmail.com') ||
        email.endsWith('@unicartagena.edu.co'))) {
      _showMessage(
        'Correo inválido. Usa un correo @gmail.com o @unicartagena.edu.co',
      );
      return;
    }

    setState(() => isLoading = true);

    final res = await http.post(
      Uri.parse('http://localhost:5000/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    setState(() => isLoading = false);

    if (res.statusCode == 200) {
      _showMessage('Correo enviado. Revisa tu bandeja de entrada.');
    } else {
      _showMessage('No se pudo enviar el correo.');
    }
  }

  Future<void> verifySecretAnswer() async {
    final email = emailCtrl.text.trim();
    final question = selectedQuestion;
    final answer = answerCtrl.text.trim();

    if (email.isEmpty || question == secretQuestions[0] || answer.isEmpty) {
      _showMessage('Completa todos los campos requeridos.');
      return;
    }

    final newPassword = await _askForNewPassword();
    if (newPassword == null || newPassword.isEmpty) return;

    final res = await http.post(
      Uri.parse('http://localhost:5000/api/auth/secret-recovery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'secretQuestion': question,
        'secretAnswer': answer,
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      _showMessage('Contraseña restablecida exitosamente.');
      await Future.delayed(const Duration(seconds: 4));
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showMessage(data['msg'] ?? 'Error al recuperar contraseña.');
    }
  }

  Future<String?> _askForNewPassword() async {
    String password = '';
    bool showPassword = false;
    double strength = 0;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void checkStrength(String value) {
              password = value;
              double newStrength = 0;

              if (value.isEmpty) {
                newStrength = 0;
              } else if (value.length < 6) {
                newStrength = 0.25;
              } else if (value.contains(RegExp(r'[A-Z]')) &&
                  value.contains(RegExp(r'[0-9]'))) {
                newStrength = 0.75;
              } else if (value.length >= 8 &&
                  value.contains(RegExp(r'[A-Z]')) &&
                  value.contains(RegExp(r'[0-9]')) &&
                  value.contains(RegExp(r'[!@#\$&*~]'))) {
                newStrength = 1.0;
              } else {
                newStrength = 0.5;
              }

              setState(() {
                strength = newStrength;
              });
            }

            Color getStrengthColor(double strength) {
              if (strength <= 0.25) return Colors.red;
              if (strength <= 0.5) return Colors.orange;
              if (strength <= 0.75) return Colors.amber;
              return Colors.green;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Establecer nueva contraseña'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: !showPassword,
                    onChanged: checkStrength,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: strength,
                    minHeight: 6,
                    color: getStrengthColor(strength),
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strength == 0
                        ? 'Muy débil'
                        : strength <= 0.25
                        ? 'Débil'
                        : strength <= 0.5
                        ? 'Regular'
                        : strength <= 0.75
                        ? 'Fuerte'
                        : 'Muy fuerte',
                    style: TextStyle(
                      color: getStrengthColor(strength),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: password.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(password),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF00838F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const FloatingParticles(numberOfParticles: 50, color: Colors.white),
          Center(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 600;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isWide)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 24.0),
                              child: SvgPicture.asset(
                                'lib/assets/images/forgot_password.svg',
                                height: 300,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Card(
                            elevation: 8,
                            color: Colors.white.withOpacity(0.95),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      '¿Olvidaste tu contraseña?',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Puedes recuperarla por correo o usando tu pregunta secreta.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    TextField(
                                      controller: emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Correo electrónico',
                                        prefixIcon: const Icon(Icons.email),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value: selectedQuestion,
                                      items: secretQuestions.map((question) {
                                        return DropdownMenuItem(
                                          value: question,
                                          child: Text(question),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedQuestion = value!;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Pregunta secreta',
                                        prefixIcon: const Icon(
                                          Icons.help_outline,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (selectedQuestion != null &&
                                        selectedQuestion != secretQuestions[0])
                                      TextField(
                                        controller: answerCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Respuesta secreta',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : sendRecoveryEmail,
                                      icon: isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.email),
                                      label: Text(
                                        isLoading
                                            ? 'Enviando...'
                                            : 'Recuperar por correo',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed:
                                          selectedQuestion == secretQuestions[0]
                                          ? null
                                          : verifySecretAnswer,
                                      icon: const Icon(Icons.vpn_key),
                                      label: const Text(
                                        'Recuperar por respuesta secreta',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
