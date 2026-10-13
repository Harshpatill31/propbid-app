import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please login again');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse('$apiBaseUrl$path'),
              headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 60)); // Render free tier cold start
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      String msg = 'Something went wrong';
      try {
        msg = jsonDecode(res.body)['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    } on TimeoutException {
      throw Exception('Server is waking up, please try again in a moment');
    } on http.ClientException {
      throw Exception('No internet / server unreachable');
    }
  }

  static Future<void> createProperty(Map<String, dynamic> data) =>
      _post('/api/properties', data);

  static Future<void> placeBid(String propertyId, double amount) =>
      _post('/api/properties/$propertyId/bids', {'amount': amount});
}

String cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
