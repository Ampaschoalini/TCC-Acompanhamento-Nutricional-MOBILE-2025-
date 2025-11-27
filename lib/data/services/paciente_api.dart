import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PacienteApi {
  // Emulador Android = 10.0.2.2 | Dispositivo físico = IP da sua máquina
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
  ///
  /// Comportamento:
  /// - Se a API responder 200, usa os dados do backend e sincroniza o SharedPreferences.
  /// - Se a API retornar erro ou a conexão falhar, tenta montar um perfil básico a partir do SharedPreferences.
  /// - Se nem o backend nem o SharedPreferences tiverem dados, retorna um Map vazio em vez de lançar Exception.
  Future<Map<String, dynamic>> getById() async {
    final token = await _token();
    final id = await _pacienteId();
    if (id == null) {
      throw Exception('paciente_id não encontrado no SharedPreferences');
    }

    final url = Uri.parse('$baseUrl/patient/getPatientById/$id');

    // Lê o que tiver no SharedPreferences (pode ser usado como fallback)
    Future<Map<String, dynamic>?> _loadFromPrefs() async {
      final prefs = await SharedPreferences.getInstance();
      final nome = prefs.getString('nome') ?? '';
      final email = prefs.getString('email') ?? '';
      final telefone = prefs.getString('telefone') ?? '';
      final dataNascimento = prefs.getString('dataNascimento') ?? '';
      final tipo = prefs.getString('tipo') ?? '';

      final hasData = [
        nome,
        email,
        telefone,
        dataNascimento,
        tipo,
      ].any((v) => v.isNotEmpty);

      if (!hasData) return null;

      return {
        'nome': nome,
        'email': email,
        'telefone': telefone,
        'dataNascimento': dataNascimento,
        'tipo': tipo,
      };
    }

    try {
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        Map<String, dynamic> patient;
        if (data is List && data.isNotEmpty) {
          patient = Map<String, dynamic>.from(data[0]);
        } else if (data is Map) {
          patient = Map<String, dynamic>.from(
            data.cast<String, dynamic>(),
          );
        } else {
          // Formato estranho -> tenta prefs
          final local = await _loadFromPrefs();
          return local ?? <String, dynamic>{};
        }

        // 🔄 Sincroniza campos básicos com SharedPreferences (para uso offline)
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('nome', patient['nome']?.toString() ?? '');
          prefs.setString('email', patient['email']?.toString() ?? '');
          prefs.setString(
            'telefone',
            (patient['telefone'] ?? patient['phone'])?.toString() ?? '',
          );
          prefs.setString(
            'dataNascimento',
            (patient['dataNascimento'] ?? patient['data_nascimento'])
                ?.toString() ??
                '',
          );
          prefs.setString('tipo', patient['tipo']?.toString() ?? '');
        } catch (_) {
          // erro ao sincronizar prefs não deve quebrar nada
        }

        return patient;
      } else {
        // HTTP 4xx/5xx -> tenta dados locais
        final local = await _loadFromPrefs();
        if (local != null) return local;

        // Sem dados locais -> devolve mapa vazio
        return <String, dynamic>{};
      }
    } catch (_) {
      // Aqui pega erros de conexão (Connection failed, timeout etc.)
      final local = await _loadFromPrefs();
      if (local != null) return local;

      // Sem dados locais -> devolve mapa vazio em vez de Exception
      return <String, dynamic>{};
    }
  }

  /// PUT /patient/updatePatientById/{id}
  /// Atualiza no backend e sincroniza campos básicos no SharedPreferences.
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
      throw Exception(
        'Erro ao atualizar perfil: ${_extractServerMessage(resp)}',
      );
    }

    // 🔄 Atualiza também o SharedPreferences com o que foi alterado
    try {
      final prefs = await SharedPreferences.getInstance();

      if (payload['nome'] != null) {
        prefs.setString('nome', payload['nome'].toString());
      }
      if (payload['email'] != null) {
        prefs.setString('email', payload['email'].toString());
      }
      if (payload['telefone'] != null) {
        prefs.setString('telefone', payload['telefone'].toString());
      }
      if (payload['dataNascimento'] != null) {
        prefs.setString(
          'dataNascimento',
          payload['dataNascimento'].toString(),
        );
      }
      if (payload['tipo'] != null) {
        prefs.setString('tipo', payload['tipo'].toString());
      }
    } catch (_) {
      // Falha de sync local não impede o sucesso da atualização remota
    }
  }

  /// Trocar senha usando o mesmo endpoint de update do paciente.
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
      throw Exception(
        'Erro ao alterar senha: ${_extractServerMessage(resp)}',
      );
    }

    // Aqui você poderia atualizar SQLite com a nova senha se quiser,
    // mas o login offline já está funcionando bem do jeito atual.
  }

  // --- Utilitário para extrair mensagem dos erros da API ---
  String _extractServerMessage(http.Response resp) {
    final status = resp.statusCode;
    final ct = resp.headers['content-type'] ?? '';
    try {
      if (ct.contains('application/json')) {
        final j = jsonDecode(resp.body);
        return j['message']?.toString() ??
            j['error']?.toString() ??
            resp.body;
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
