import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_database_service.dart';

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
  /// - Se a API responder 200, usa os dados do backend e sincroniza SharedPreferences e SQLite.
  /// - Se a API retornar erro ou a conexão falhar, tenta montar um perfil a partir do SQLite (completo) ou SharedPreferences (básico).
  /// - Se nem o backend nem os caches tiverem dados, retorna um Map vazio em vez de lançar Exception.
  Future<Map<String, dynamic>> getById() async {
    final token = await _token();
    final id = await _pacienteId();
    if (id == null) {
      throw Exception('paciente_id não encontrado no SharedPreferences');
    }

    final url = Uri.parse('$baseUrl/patient/getPatientById/$id');

    // Lê o que tiver no SharedPreferences (pode ser usado como fallback básico)
    Future<Map<String, dynamic>?> _loadFromPrefs() async {
      final prefs = await SharedPreferences.getInstance();
      final nome = prefs.getString('nome') ?? '';
      final email = prefs.getString('email') ?? '';
      final telefone = prefs.getString('telefone') ?? '';
      final dataNascimento = prefs.getString('dataNascimento') ?? '';
      final tipo = prefs.getString('tipo') ?? '';

      final hasData = <String>[
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

    // Lê o que tiver no SQLite (tabela user) para uso offline mais completo
    Future<Map<String, dynamic>?> _loadFromSQLite() async {
      try {
        if (id == null) return null;
        final localDb = LocalDatabaseService();
        final user = await localDb.getUserById(id!);
        if (user == null) return null;

        return {
          'nome': user['nome'],
          'email': user['email'],
          'telefone': user['telefone'],
          'dataNascimento': user['dataNascimento'],
          'tipo': user['tipo'],
          'genero': user['genero'],
          'objetivo': user['objetivo'],
          'frequencia_exercicio_semanal':
          user['frequencia_exercicio_semanal'],
          'restricao_alimentar': user['restricao_alimentar'],
          'alergia': user['alergia'],
          'observacao': user['observacao'],
          'habitos_alimentares': user['habitos_alimentares'],
          'historico_familiar_doencas':
          user['historico_familiar_doencas'],
          'doencas_cronicas': user['doencas_cronicas'],
          'medicamentos_em_uso': user['medicamentos_em_uso'],
          'exames_de_sangue_relevantes':
          user['exames_de_sangue_relevantes'],
        };
      } catch (_) {
        return null;
      }
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
          // Formato estranho -> tenta dados locais
          final localSql = await _loadFromSQLite();
          if (localSql != null) return localSql;
          final localPrefs = await _loadFromPrefs();
          return localPrefs ?? <String, dynamic>{};
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

        // 🔄 Sincroniza snapshot completo no SQLite para uso offline
        try {
          if (id != null) {
            final localDb = LocalDatabaseService();
            await localDb.saveUser({
              'id': id,
              'nome': patient['nome']?.toString(),
              'email': patient['email']?.toString(),
              'telefone':
              (patient['telefone'] ?? patient['phone'])?.toString(),
              'dataNascimento':
              (patient['dataNascimento'] ?? patient['data_nascimento'])
                  ?.toString(),
              'tipo': patient['tipo']?.toString(),
              'genero': patient['genero']?.toString(),
              'objetivo': patient['objetivo']?.toString(),
              'frequencia_exercicio_semanal':
              patient['frequencia_exercicio_semanal']?.toString(),
              'restricao_alimentar':
              patient['restricao_alimentar']?.toString(),
              'alergia': patient['alergia']?.toString(),
              'observacao': patient['observacao']?.toString(),
              'habitos_alimentares':
              patient['habitos_alimentares']?.toString(),
              'historico_familiar_doencas':
              patient['historico_familiar_doencas']?.toString(),
              'doencas_cronicas':
              patient['doencas_cronicas']?.toString(),
              'medicamentos_em_uso':
              patient['medicamentos_em_uso']?.toString(),
              'exames_de_sangue_relevantes':
              patient['exames_de_sangue_relevantes']?.toString(),
            });
          }
        } catch (_) {
          // falha de sync local não deve impedir o fluxo normal
        }

        return patient;
      } else {
        // HTTP 4xx/5xx -> tenta dados locais
        final localSql = await _loadFromSQLite();
        if (localSql != null) return localSql;

        final localPrefs = await _loadFromPrefs();
        if (localPrefs != null) return localPrefs;

        // Sem dados locais -> devolve mapa vazio
        return <String, dynamic>{};
      }
    } catch (_) {
      // Aqui pega erros de conexão (Connection failed, timeout etc.)
      final localSql = await _loadFromSQLite();
      if (localSql != null) return localSql;

      final localPrefs = await _loadFromPrefs();
      if (localPrefs != null) return localPrefs;

      // Sem dados locais -> devolve mapa vazio em vez de Exception
      return <String, dynamic>{};
    }
  }

  /// PUT /patient/updatePatientById/{id}
  /// Atualiza no backend, SharedPreferences e SQLite (perfil offline).
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

    // 🔄 Atualiza snapshot local no SQLite (se existir)
    try {
      final localDb = LocalDatabaseService();
      await localDb.updateUserPartial(
        id: id!,
        nome: payload['nome']?.toString(),
        email: payload['email']?.toString(),
        telefone: payload['telefone']?.toString(),
        dataNascimento: payload['dataNascimento']?.toString(),
        tipo: payload['tipo']?.toString(),
        genero: payload['genero']?.toString(),
        objetivo: payload['objetivo']?.toString(),
        frequenciaExercicioSemanal:
        payload['frequencia_exercicio_semanal']?.toString(),
        restricaoAlimentar:
        payload['restricao_alimentar']?.toString(),
        alergia: payload['alergia']?.toString(),
        observacao: payload['observacao']?.toString(),
        habitosAlimentares:
        payload['habitos_alimentares']?.toString(),
        historicoFamiliarDoencas:
        payload['historico_familiar_doencas']?.toString(),
        doencasCronicas:
        payload['doencas_cronicas']?.toString(),
        medicamentosEmUso:
        payload['medicamentos_em_uso']?.toString(),
        examesDeSangueRelevantes:
        payload['exames_de_sangue_relevantes']?.toString(),
      );
    } catch (_) {
      // Falha de sync local não deve quebrar fluxo
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
        'Erro ao trocar senha: ${_extractServerMessage(resp)}',
      );
    }
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
