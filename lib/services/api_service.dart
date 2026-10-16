import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/training_session.dart';

class ApiService {
  static const _baseUrl = 'https://jsonplaceholder.typicode.com';

  Future<List<TrainingSession>> fetchSessions() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/todos?_limit=12'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteSession(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/todos/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }
}