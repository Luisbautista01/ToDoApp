// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_tareas_app/screen/floating_particles.dart';
import 'package:gestor_tareas_app/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  final AuthService authService;
  const RegisterPage({required this.authService, super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final userCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final questionCtrl = TextEditingController();
  final answerCtrl = TextEditingController();

  bool showPassword = false;
  double passwordStrength = 0;
  bool _isRegistering = false;

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  String? selectedQuestion;
  late List<String> secretQuestions;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

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

  @override
  void dispose() {
    _controller.dispose();
    userCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    questionCtrl.dispose();
    answerCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _validateInputs() {
    final username = userCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    final emailFormatRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    final allowedDomains = ['@gmail.com', '@unicartagena.edu.co'];
    final upperRegex = RegExp(r'[A-Z]');
    final numberRegex = RegExp(r'[0-9]');
    final specialCharRegex = RegExp(r'[!@#\$%^&*(),.?":{}|<>]');

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        selectedQuestion == secretQuestions[0] ||
        answerCtrl.text.trim().isEmpty) {
      _showError('Todos los campos son obligatorios.');
      return false;
    }

    if (username.length < 4) {
      _showError('El nombre de usuario debe tener al menos 4 caracteres.');
      return false;
    }

    if (!emailFormatRegex.hasMatch(email)) {
      _showError('Formato de correo inválido.');
      return false;
    }

    if (!allowedDomains.any((domain) => email.endsWith(domain))) {
      _showError(
        'El correo debe terminar en @gmail.com o @unicartagena.edu.co',
      );
      return false;
    }

    if (password.length < 8) {
      _showError('La contraseña debe tener al menos 8 caracteres.');
      return false;
    }

    if (!upperRegex.hasMatch(password)) {
      _showError('La contraseña necesita al menos una letra mayúscula.');
      return false;
    }

    if (!numberRegex.hasMatch(password)) {
      _showError('La contraseña necesita al menos un número.');
      return false;
    }

    if (!specialCharRegex.hasMatch(password)) {
      _showError('La contraseña necesita un carácter especial.');
      return false;
    }

    return true;
  }

  void _register() async {
    if (!_validateInputs()) return;

    setState(() => _isRegistering = true);

    try {
      bool success = await widget.authService.register(
        userCtrl.text.trim(),
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
        selectedQuestion!,
        answerCtrl.text.trim(),
      );

      setState(() => _isRegistering = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario registrado correctamente. Inicia sesión.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showError('Este correo ya se encuentra registrado.');
      }
    } catch (e) {
      setState(() => _isRegistering = false);
      _showError('Error inesperado: ${e.toString()}');
    }
  }

  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;
    setState(() {
      passwordStrength = strength;
    });
  }

  Color _getStrengthColor() {
    if (passwordStrength <= 0.25) return Colors.red;
    if (passwordStrength <= 0.5) return Colors.orange;
    if (passwordStrength <= 0.75) return Colors.amber;
    return Colors.green;
  }

  IconData _getStrengthIcon() {
    if (passwordStrength < 0.3) return Icons.lock_open;
    if (passwordStrength < 0.7) return Icons.lock_outline;
    return Icons.lock;
  }

  String _getStrengthLabel() {
    if (passwordStrength <= 0.25) return 'Débil';
    if (passwordStrength <= 0.5) return 'Regular';
    if (passwordStrength <= 0.75) return 'Buena';
    return 'Fuerte';
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.grey.shade100,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
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
          const FloatingParticles(numberOfParticles: 80, color: Colors.white),
          Center(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 600;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isWide)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 24.0),
                              child: SvgPicture.asset(
                                'lib/assets/images/signup.svg',
                                height: 300,
                              ),
                            ),
                          ),
                        Expanded(
                          child: FadeTransition(
                            opacity: _opacityAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Crear cuenta',
                                        style: GoogleFonts.poppins(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        controller: userCtrl,
                                        label: 'Usuario',
                                        icon: Icons.person,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: emailCtrl,
                                        label: 'Correo',
                                        icon: Icons.email,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: passCtrl,
                                        label: 'Contraseña',
                                        icon: Icons.lock,
                                        obscure: !showPassword,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            showPassword
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () => setState(
                                            () => showPassword = !showPassword,
                                          ),
                                        ),
                                        onChanged: _updatePasswordStrength,
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _getStrengthColor(),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getStrengthIcon(),
                                              color: _getStrengthColor(),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  LinearProgressIndicator(
                                                    value: passwordStrength,
                                                    backgroundColor:
                                                        Colors.grey[300],
                                                    color: _getStrengthColor(),
                                                    minHeight: 6,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Seguridad: ${_getStrengthLabel()}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          _getStrengthColor(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<String>(
                                        value: selectedQuestion,
                                        decoration: InputDecoration(
                                          labelText: 'Pregunta secreta',
                                          prefixIcon: const Icon(
                                            Icons.help_outline,
                                            color: Colors.teal,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                        ),
                                        items: secretQuestions.map((question) {
                                          return DropdownMenuItem<String>(
                                            value: question,
                                            child: Text(question),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedQuestion = value;
                                          });
                                        },
                                        validator: (value) => value == null
                                            ? 'Selecciona una pregunta secreta'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: answerCtrl,
                                        label: 'Respuesta secreta',
                                        icon: Icons.lock_outline,
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _isRegistering
                                            ? null
                                            : _register,
                                        icon: _isRegistering
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person_add,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isRegistering
                                              ? 'Registrando...'
                                              : 'Registrar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          minimumSize: const Size(120, 40),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.tealAccent,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/login',
                                            ),
                                        child: Text(
                                          '¿Ya tienes cuenta? Inicia sesión',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
