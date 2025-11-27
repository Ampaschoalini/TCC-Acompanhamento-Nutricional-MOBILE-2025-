import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'local_database_service.dart';

class NutricionistaService {
  final String baseUrl =
      'http://10.0.2.2:8800/nutricionist/getNutricionistById';

  final LocalDatabaseService _localDb = LocalDatabaseService();

  Future<bool> _isOffline() async {
    final result = await Connectivity().checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  /// Busca o nutricionista online; se falhar ou estiver offline, usa o cache do SQLite.
  Future<Map<String, dynamic>?> getNutricionistaById(int id) async {
    final offline = await _isOffline();

    if (offline) {
      // Sem internet → tenta direto o cache local
      return _localDb.getNutricionistaById(id);
    }

    try {
      final uri = Uri.parse('$baseUrl/$id');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        Map<String, dynamic>? nutri;
        if (data is List && data.isNotEmpty) {
          nutri = Map<String, dynamic>.from(data[0]);
        } else if (data is Map) {
          nutri = Map<String, dynamic>.from(
              data.cast<String, dynamic>());
        }

        if (nutri != null) {
          // Atualiza cache local
          await _localDb.saveNutricionista(nutri);
        }

        return nutri;
      } else {
        // Erro HTTP → tenta usar cache
        // ignore: avoid_print
        print(
          'Erro HTTP em getNutricionistById: '
              'status=${response.statusCode} body=${response.body}',
        );
        return _localDb.getNutricionistaById(id);
      }
    } catch (e) {
      // Erro de conexão ("Connection failed", timeout, etc.) → cache
      // ignore: avoid_print
      print('Erro de conexão em getNutricionistById: $e');
      return _localDb.getNutricionistaById(id);
    }
  }
}
