// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String _baseUrl = 'http://localhost:5000/api';

  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? get currentUser => _currentUser;

  Future<bool> register(
    String username,
    String email,
    String password,
    String secretQuestion,
    String secretAnswer,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'secretQuestion': secretQuestion,
          'secretAnswer': secretAnswer,
        }),
      );

      if (res.statusCode == 201) {
        final token = jsonDecode(res.body)['token'];
        await saveToken(token);
        await fetchUserProfile(); // Guardar usuario en memoria
        return true;
      } else {
        final error = jsonDecode(res.body)['error'] ?? 'Error desconocido';
        print('Error de registro: $error');
        return false;
      }
    } catch (e) {
      print('Excepción durante el registro: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final token = jsonDecode(res.body)['token'];
        await saveToken(token);
        await fetchUserProfile(); // Guardar usuario en memoria
        return true;
      } else {
        print('Login fallido: ${res.body}');
        return false;
      }
    } catch (e) {
      print('Error durante login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _currentUser = null;
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    print('Token guardado en local: $token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> saveLoginInfo(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setString('password', password);
  }

  Future<Map<String, String?>> getSavedLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('email'),
      'password': prefs.getString('password'),
    };
  }

  Future<void> fetchUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        _currentUser = jsonDecode(res.body);
        print('Usuario cargado: $_currentUser');
      } else {
        print('Error al cargar perfil: ${res.body}');
      }
    } catch (e) {
      print('Error al obtener perfil: $e');
    }
  }
}
