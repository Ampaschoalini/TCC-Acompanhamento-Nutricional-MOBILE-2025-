import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/services/local_database_service.dart';
import '../../data/services/plano_alimentar_service.dart';

class AuthService {
  // Emulador Android = 10.0.2.2 | Dispositivo físico = IP da máquina
  final String baseUrl = 'http://10.0.2.2:8800';
  final LocalDatabaseService localDb = LocalDatabaseService();

  /// Login híbrido: tenta online; se não conseguir falar com o servidor, cai para o SQLite.
  Future<bool> login(String email, String senha) async {
    final connectivityStatus = await Connectivity().checkConnectivity();

    // Compatível com versões novas/antigas do connectivity_plus
    final bool isOffline = connectivityStatus is List<ConnectivityResult>
        ? connectivityStatus.contains(ConnectivityResult.none)
        : connectivityStatus == ConnectivityResult.none;

    // Se já detectou que está offline, nem tenta chamar o backend
    if (isOffline) {
      return _loginOffline(email, senha);
    }

    try {
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "senha": senha}),
      );

      print('LOGIN status=${response.statusCode} body=${response.body}');

      // Credenciais erradas de fato (resposta do backend)
      if (response.statusCode == 400 || response.statusCode == 401) {
        return false;
      }

      // Login ONLINE OK
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Token pode vir em chaves diferentes
        final String? token =
        (data['token'] ?? data['accessToken'] ?? data['access_token'])
            ?.toString();

        // Tenta achar o objeto de usuário em chaves diferentes
        Map<String, dynamic>? user =
        (data['user'] as Map?)?.cast<String, dynamic>();
        user ??= (data['paciente'] as Map?)?.cast<String, dynamic>();
        user ??= (data['patient'] as Map?)?.cast<String, dynamic>();

        // Se a API já devolve o user no root
        if (user == null && data['id'] != null) {
          user = Map<String, dynamic>.from(data);
        }

        if (user == null || token == null || user['id'] == null) {
          return false;
        }

        // Normaliza campos
        user['dataNascimento'] =
            user['dataNascimento'] ?? user['data_nascimento'];
        user['telefone'] = user['telefone'] ?? user['phone'];

        user['nutricionista_id'] = user['nutricionista_id'] ??
            user['nutricionistaId'] ??
            user['nutritionist_id'];

        // Salva no SharedPreferences
        await _salvarPrefs(user, token: token);

        // Salva/atualiza no SQLite para login offline
        await localDb.saveUser({
          'id': user['id'],
          'nome': user['nome'],
          'email': user['email'],
          // SENHA digitada no login online (não vem do backend)
          'senha': senha,
          'tipo': user['tipo'],
          'telefone': user['telefone'] ?? '',
          'dataNascimento': user['dataNascimento'] ?? '',
        });

        // Pré-carrega plano alimentar (cache offline)
        try {
          final planoService = PlanoAlimentarService();

          final rawId = user['id'];
          final int? pacienteId =
          rawId is int ? rawId : int.tryParse(rawId.toString());

          if (pacienteId != null && pacienteId > 0) {
            await planoService.getDietasByPacienteId(pacienteId);
          }
        } catch (e) {
          print('Falha ao pré-carregar plano alimentar: $e');
        }

        return true;
      }

      // Qualquer outro status (500, etc) -> tenta offline
      return _loginOffline(email, senha);
    } catch (e) {
      // Erros de rede / timeout / etc -> tenta offline
      print('Erro no login online, tentando offline: $e');
      return _loginOffline(email, senha);
    }
  }

  /// Tenta login usando apenas o SQLite.
  Future<bool> _loginOffline(String email, String senha) async {
    final localUser =
    await localDb.getUserByEmailAndPassword(email, senha);

    if (localUser == null) {
      print('LOGIN OFFLINE FALHOU para $email');
      return false;
    }

    // Monta um mapa compatível com o que _salvarPrefs espera,
    // usando os dados armazenados na tabela local `user`.
    final userMap = <String, dynamic>{
      'id': localUser['id'],
      'nome': localUser['nome'],
      'email': localUser['email'],
      'tipo': localUser['tipo'] ?? 'paciente',
      'telefone': localUser['telefone'],
      'dataNascimento': localUser['dataNascimento'],
    };

    // Atualiza o SharedPreferences com o usuário logado offline
    await _salvarPrefs(userMap);

    print('LOGIN OFFLINE OK para $email');
    return true;
  }

  Future<Map<String, dynamic>> getUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getInt('user_id') ?? 0,
      'paciente_id': prefs.getInt('paciente_id') ?? 0,
      'nome': prefs.getString('nome') ?? '',
      'email': prefs.getString('email') ?? '',
      'tipo': prefs.getString('tipo') ?? '',
      'telefone': prefs.getString('telefone') ?? '',
      'dataNascimento': prefs.getString('dataNascimento') ?? '',
      'nutricionista_id': prefs.getInt('nutricionista_id') ?? 0,
    };
  }

  Future<void> _salvarPrefs(Map<String, dynamic> user, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();

    if (token != null) {
      await prefs.setString('token', token);
    }

    await prefs.setInt('user_id', user['id']);

    if (user['tipo']?.toString().toLowerCase() == 'paciente' ||
        user.containsKey('paciente_id')) {
      await prefs.setInt('paciente_id', user['id']);
    }

    await prefs.setString('nome', user['nome'] ?? '');
    await prefs.setString('email', user['email'] ?? '');
    await prefs.setString('tipo', user['tipo'] ?? '');
    await prefs.setString('telefone', user['telefone']?.toString() ?? '');
    await prefs.setString(
      'dataNascimento',
      user['dataNascimento']?.toString() ?? '',
    );

    if (user.containsKey('nutricionista_id') &&
        user['nutricionista_id'] != null) {
      final raw = user['nutricionista_id'];
      final int? nutriId =
      raw is int ? raw : int.tryParse(raw.toString());
      if (nutriId != null) {
        await prefs.setInt('nutricionista_id', nutriId);
      }
    }
  }
}
