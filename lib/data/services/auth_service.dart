import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/local_database_service.dart';

class AuthService {
  // Emulador Android = 10.0.2.2 | Dispositivo físico = IP da sua máquina
  final String baseUrl = 'http://10.0.2.2:8800';
  final LocalDatabaseService localDb = LocalDatabaseService();

  /// 🔐 Login com suporte offline + normalização de chaves (snake_case/camelCase)
  Future<bool> login(String email, String senha) async {
    final connectivityStatus = await Connectivity().checkConnectivity();

    final bool isOffline = connectivityStatus is List<ConnectivityResult>
        ? connectivityStatus.contains(ConnectivityResult.none)
        : connectivityStatus == ConnectivityResult.none;

    if (isOffline) {
      final localUser = await localDb.getUserByEmailAndPassword(email, senha);
      if (localUser != null) {
        await _salvarPrefs(localUser, token: null);
        return true;
      }
      return false;
    }

    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "senha": senha}),
    );

    print('LOGIN status=${response.statusCode} body=${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final String? token = (data['token'] ?? data['accessToken'] ?? data['access_token'])?.toString();

      Map<String, dynamic>? user = (data['user'] as Map?)?.cast<String, dynamic>();
      user ??= (data['paciente'] as Map?)?.cast<String, dynamic>();
      user ??= (data['patient'] as Map?)?.cast<String, dynamic>();
      if (user == null && data['id'] != null) {
        user = Map<String, dynamic>.from(data);
      }

      if (user == null || token == null || user['id'] == null) return false;

      user['dataNascimento'] = user['dataNascimento'] ?? user['data_nascimento'];
      user['telefone'] = user['telefone'] ?? user['phone'];

      await _salvarPrefs(user, token: token);

      await localDb.saveUser({
        'id': user['id'],
        'nome': user['nome'],
        'email': user['email'],
        'senha': senha,
        'tipo': user['tipo'],
        'telefone': user['telefone'] ?? '',
        'dataNascimento': user['dataNascimento'] ?? '',
      });

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
    };
  }

  /// 🧠 Utilitário para salvar no SharedPreferences
  Future<void> _salvarPrefs(Map<String, dynamic> user, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) await prefs.setString('token', token);

    // sempre salva o id
    await prefs.setInt('user_id', user['id']);

    // se for paciente, salva também como paciente_id
    if (user['tipo']?.toString().toLowerCase() == 'paciente' || user.containsKey('paciente_id')) {
      await prefs.setInt('paciente_id', user['id']);
    }

    await prefs.setString('nome', user['nome'] ?? '');
    await prefs.setString('email', user['email'] ?? '');
    await prefs.setString('tipo', user['tipo'] ?? '');
    await prefs.setString('telefone', user['telefone']?.toString() ?? '');
    await prefs.setString('dataNascimento', user['dataNascimento']?.toString() ?? '');

    if (user.containsKey('nutricionista_id') && user['nutricionista_id'] != null) {
      await prefs.setInt('nutricionista_id', user['nutricionista_id']);
    }
  }
}
