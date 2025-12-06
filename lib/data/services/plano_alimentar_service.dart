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

    // compatível com versões que retornam lista ou um único enum
    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  /// Busca as dietas do paciente, com fallback para o cache local.
  Future<List<Dieta>> getDietasByPacienteId(int pacienteId) async {
    final offline = await _isOffline();

    // 1) Sem conexão → usa só o cache local
    if (offline) {
      return _localDb.getPlano(pacienteId);
    }

    List<Dieta> dietas;

    // 2) Com conexão → tenta API
    try {
      dietas = await _remote.getDietasByPacienteId(pacienteId);
    } catch (e) {
      final locais = await _localDb.getPlano(pacienteId);
      if (locais.isNotEmpty) return locais;
      return <Dieta>[];
    }

    // 3) Se a API devolveu vazio, preferimos o cache (se existir)
    if (dietas.isEmpty) {
      final locais = await _localDb.getPlano(pacienteId);
      if (locais.isNotEmpty) return locais;
      return <Dieta>[];
    }

    // 4) API trouxe dados válidos → atualiza cache e retorna
    await _localDb.salvarPlano(pacienteId, dietas);
    return dietas;
  }
}
