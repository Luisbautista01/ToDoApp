// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_tareas_app/screen/floating_particles.dart';
import 'package:gestor_tareas_app/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final AuthService authService;
  const LoginPage({required this.authService, super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPassword = false;
  bool rememberMe = false;
  bool _isLoading = false; // ← Nuevo

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

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
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() async {
    final saved = await widget.authService.getSavedLoginInfo();
    setState(() {
      emailCtrl.text = saved['email'] ?? '';
      passCtrl.text = saved['password'] ?? '';
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _validateInputs() {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    final emailFormatRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    final allowedDomains = ['@gmail.com', '@unicartagena.edu.co'];
    final upperRegex = RegExp(r'[A-Z]');
    final numberRegex = RegExp(r'[0-9]');
    final specialCharRegex = RegExp(r'[!@#\$%^&*(),.?":{}|<>]');

    if (email.isEmpty || password.isEmpty) {
      _showError('Todos los campos son obligatorios.');
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

  Future<void> _login() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true); // ← Activar loading

    final success = await widget.authService.login(
      emailCtrl.text,
      passCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      if (rememberMe) {
        await widget.authService.saveLoginInfo(emailCtrl.text, passCtrl.text);
      }
      Navigator.pushReplacementNamed(context, '/tasks');
    } else {
      _showError('Correo o contraseña incorrectos.');
    }

    setState(() => _isLoading = false); // ← Desactivar loading
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
          const FloatingParticles(numberOfParticles: 60, color: Colors.white),
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
                              padding: const EdgeInsets.only(right: 24),
                              child: SvgPicture.asset(
                                'lib/assets/images/login.svg',
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
                                        'Bienvenido a TO DO',
                                        style: GoogleFonts.poppins(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        controller: emailCtrl,
                                        label: 'Correo electrónico',
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
                                      ),
                                      const SizedBox(height: 8),
                                      CheckboxListTile(
                                        value: rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            rememberMe = value ?? false;
                                          });
                                        },
                                        title: const Text('Recordar usuario'),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _isLoading ? null : _login,
                                        icon: _isLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(Icons.login, size: 18),
                                        label: Text(
                                          _isLoading
                                              ? 'Iniciando...'
                                              : 'Iniciar sesión',
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
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pushReplacementNamed(
                                              context,
                                              '/register',
                                            ),
                                        child: Text(
                                          '¿No tienes cuenta? Regístrate',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/forgot-password',
                                        ),
                                        child: Text(
                                          '¿Olvidaste tu contraseña?',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}
