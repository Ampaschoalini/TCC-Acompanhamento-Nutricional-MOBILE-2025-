import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/local_database_service.dart';

class AuthService {
  // Emulador Android = 10.0.2.2 | Dispositivo físico = IP da sua máquina
  final String baseUrl = 'http://10.0.2.2:8800';
  final LocalDatabaseService localDb = LocalDatabaseService();

  /// 🔐 Login híbrido: tenta online; se não conseguir falar com o servidor, cai para o SQLite.
  Future<bool> login(String email, String senha) async {
    final connectivityStatus = await Connectivity().checkConnectivity();

    final bool isOffline = connectivityStatus is List<ConnectivityResult>
        ? connectivityStatus.contains(ConnectivityResult.none)
        : connectivityStatus == ConnectivityResult.none;

    // 1) Sem conexão alguma -> tenta direto o SQLite
    if (isOffline) {
      return _loginOffline(email, senha);
    }

    // 2) Com conexão: tenta o backend, e em caso de erro de rede, cai para o SQLite
    try {
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "senha": senha}),
      );

      print('LOGIN status=${response.statusCode} body=${response.body}');

      // Credenciais inválidas: não faz fallback offline
      if (response.statusCode == 400 || response.statusCode == 401) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final String? token =
        (data['token'] ?? data['accessToken'] ?? data['access_token'])
            ?.toString();

        Map<String, dynamic>? user =
        (data['user'] as Map?)?.cast<String, dynamic>();
        user ??= (data['paciente'] as Map?)?.cast<String, dynamic>();
        user ??= (data['patient'] as Map?)?.cast<String, dynamic>();

        if (user == null && data['id'] != null) {
          user = Map<String, dynamic>.from(data);
        }

        if (user == null || token == null || user['id'] == null) {
          return false;
        }

        // Normalização de campos equivalentes
        user['dataNascimento'] =
            user['dataNascimento'] ?? user['data_nascimento'];
        user['telefone'] = user['telefone'] ?? user['phone'];

        // normalizar o campo do nutricionista vindo do backend
        user['nutricionista_id'] = user['nutricionista_id'] ??
            user['nutricionistaId'] ??
            user['nutritionist_id'];

        // Salva prefs em memória
        await _salvarPrefs(user, token: token);

        // Persiste/atualiza o usuário no SQLite para login offline
        await localDb.saveUser({
          'id': user['id'],
          'nome': user['nome'],
          'email': user['email'],
          'senha': senha, // se quiser, pode trocar por hash depois
          'tipo': user['tipo'],
          'telefone': user['telefone'] ?? '',
          'dataNascimento': user['dataNascimento'] ?? '',
        });

        return true;
      }

      // Qualquer outro status (500, 503, etc.) -> tenta offline
      return _loginOffline(email, senha);
    } catch (e) {
      // Erro de rede / timeout / etc -> tenta offline
      return _loginOffline(email, senha);
    }
  }

  /// 🔐 Login somente no SQLite (modo offline)
  Future<bool> _loginOffline(String email, String senha) async {
    final localUser =
    await localDb.getUserByEmailAndPassword(email, senha);
    if (localUser != null) {
      await _salvarPrefs(localUser, token: null);
      return true;
    }
    return false;
  }

  /// 👤 Obter dados do usuário logado (cache local no SharedPreferences)
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

  /// 🧠 Utilitário para salvar no SharedPreferences
  Future<void> _salvarPrefs(Map<String, dynamic> user, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString('token', token);

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
