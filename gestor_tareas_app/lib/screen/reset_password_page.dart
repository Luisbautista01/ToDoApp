// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ResetPasswordPage extends StatefulWidget {
  final String token;
  const ResetPasswordPage({super.key, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final passwordCtrl = TextEditingController();
  bool isLoading = false;

  Future<void> resetPassword() async {
    final password = passwordCtrl.text.trim();

    if (password.length < 6) {
      _showMessage('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => isLoading = true);

    final res = await http.post(
      Uri.parse(
        'http://localhost:5000/api/auth/reset-password/${widget.token}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'newPassword': password}),
    );

    setState(() => isLoading = false);

    if (res.statusCode == 200) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Éxito'),
          content: const Text(
            'Tu contraseña ha sido restablecida correctamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // cerrar diálogo
                Navigator.pushReplacementNamed(
                  context,
                  '/login',
                ); // ajustar ruta
              },
              child: const Text('Ir a iniciar sesión'),
            ),
          ],
        ),
      );
    } else {
      _showMessage('Error: ${jsonDecode(res.body)['msg']}');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    print('TOKEN RECIBIDO: ${widget.token}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : resetPassword,
              child: Text(isLoading ? 'Cambiando...' : 'Cambiar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
