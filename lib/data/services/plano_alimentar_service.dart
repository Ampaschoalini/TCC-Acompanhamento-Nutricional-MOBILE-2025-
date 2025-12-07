import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/dieta.dart';
import 'dieta_service.dart';
import 'plano_alimentar_local_database_service.dart';

/// Serviço que mistura API + SQLite para a tela de Plano Alimentar.
class PlanoAlimentarService {
  final DietaService _remote;
  final PlanoAlimentarLocalDatabaseService _localDb;

  PlanoAlimentarService({
    DietaService? remote,
    PlanoAlimentarLocalDatabaseService? localDb,
  })  : _remote = remote ?? DietaService(),
        _localDb = localDb ?? PlanoAlimentarLocalDatabaseService();

  Future<bool> _isOffline() async {
    final result = await Connectivity().checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  /// Busca as dietas do paciente, com fallback para o cache local.
  Future<List<Dieta>> getDietasByPacienteId(int pacienteId) async {
    final offline = await _isOffline();

    if (offline) {
      final locais = await _localDb.getPlano(pacienteId);
      if (locais.isNotEmpty) return locais;

      final qualquer = await _localDb.getQualquerPlano();
      return qualquer;
    }

    List<Dieta> dietas;

    try {
      dietas = await _remote.getDietasByPacienteId(pacienteId);
    } catch (e) {
      final locais = await _localDb.getPlano(pacienteId);
      if (locais.isNotEmpty) return locais;

      final qualquer = await _localDb.getQualquerPlano();
      return qualquer;
    }

    if (dietas.isEmpty) {
      final locais = await _localDb.getPlano(pacienteId);
      if (locais.isNotEmpty) return locais;

      final qualquer = await _localDb.getQualquerPlano();
      return qualquer;
    }

    await _localDb.salvarPlano(pacienteId, dietas);
    return dietas;
  }
}
