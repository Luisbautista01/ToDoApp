import 'package:flutter/material.dart';
import 'package:gestor_tareas_app/screen/forgot_password_page.dart';
import 'package:gestor_tareas_app/screen/reset_password_page.dart';
import 'package:gestor_tareas_app/screen/login_page.dart';
import 'package:gestor_tareas_app/screen/register_page.dart';
import 'package:gestor_tareas_app/screen/task_page.dart';
import 'package:gestor_tareas_app/services/auth_service.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final AuthService authService = AuthService();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Tareas',
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password/')) {
          final token = settings.name!.split('/reset-password/').last;
          return MaterialPageRoute(
            builder: (context) => ResetPasswordPage(token: token),
          );
        }
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (_) => LoginPage(authService: authService),
            );
          case '/register':
            return MaterialPageRoute(
              builder: (_) => RegisterPage(authService: authService),
            );
          case '/tasks':
            return MaterialPageRoute(
              builder: (_) => TaskPage(authService: authService),
            );
          case '/forgot-password':
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Página no encontrada')),
              ),
            );
        }
      },
    );
  }
}
