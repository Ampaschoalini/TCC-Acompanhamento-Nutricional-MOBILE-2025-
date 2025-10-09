import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PacienteApi {
  final String baseUrl = 'http://10.0.2.2:8800';

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> _pacienteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('paciente_id');
  }

  /// GET /patient/getPatientById/{id}
  Future<Map<String, dynamic>> getById() async {
    final token = await _token();
    final id = await _pacienteId();
    if (id == null) {
      throw Exception('paciente_id não encontrado no SharedPreferences');
    }

    final url = Uri.parse('$baseUrl/patient/getPatientById/$id');
    final resp = await http.get(url, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    if (resp.statusCode != 200) {
      throw Exception('Erro ao carregar perfil: ${_extractServerMessage(resp)}');
    }

    final data = jsonDecode(resp.body);

    // Caso o backend retorne array em vez de objeto
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data[0]);
    }
    return Map<String, dynamic>.from(data);
  }

  /// PUT /patient/updatePatientById/{id}
  Future<void> updateById(Map<String, dynamic> payload) async {
    final token = await _token();
    final id = await _pacienteId();
    if (id == null) {
      throw Exception('paciente_id não encontrado no SharedPreferences');
    }

    final url = Uri.parse('$baseUrl/patient/updatePatientById/$id');
    final resp = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception('Erro ao atualizar perfil: ${_extractServerMessage(resp)}');
    }
  }

  /// Trocar senha usando o mesmo endpoint de update do paciente.
  /// O backend atualiza a senha quando os campos `senha` e `confirmar_senha` são enviados.
  /// Obs.: este backend não valida a senha atual.
  Future<void> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await _token();
    final id = await _pacienteId();
    if (id == null) {
      throw Exception('paciente_id não encontrado no SharedPreferences');
    }

    final url = Uri.parse('$baseUrl/patient/updatePatientById/$id');
    final body = jsonEncode({
      'senha': newPassword,
      'confirmar_senha': confirmPassword,
    });

    final resp = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Erro ao alterar senha: ${_extractServerMessage(resp)}');
    }
  }

  // --- Util ---
  String _extractServerMessage(http.Response resp) {
    final status = resp.statusCode;
    final ct = resp.headers['content-type'] ?? '';
    try {
      if (ct.contains('application/json')) {
        final j = jsonDecode(resp.body);
        return j['message']?.toString() ?? j['error']?.toString() ?? resp.body;
      }
      if (ct.contains('text/html')) {
        final text = resp.body
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return 'HTTP $status — $text';
      }
      return 'HTTP $status — ${resp.body}';
    } catch (_) {
      return 'HTTP $status — ${resp.body}';
    }
  }
}
