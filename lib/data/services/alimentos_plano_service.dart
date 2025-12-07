import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/dieta.dart';
import '../models/alimento.dart';
import 'dieta_service.dart';
import 'local_database_service.dart';

class AlimentosPlanoService {
  final DietaService _remote;
  final LocalDatabaseService _localDb;

  AlimentosPlanoService({
    DietaService? remote,
    LocalDatabaseService? localDb,
  })  : _remote = remote ?? DietaService(),
        _localDb = localDb ?? LocalDatabaseService();

  Future<bool> _isOffline() async {
    final result = await Connectivity().checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  /// Busca os alimentos do plano do paciente, com fallback para SQLite.
  Future<List<Alimento>> getAlimentosPlanoByPaciente(int pacienteId) async {
    final offline = await _isOffline();

    if (offline) {
      return _localDb.getAlimentosPlano();
    }

    List<Dieta> dietas;

    try {
      dietas = await _remote.getDietasByPacienteId(pacienteId);
    } catch (e) {
      final locais = await _localDb.getAlimentosPlano();
      if (locais.isNotEmpty) return locais;
      return <Alimento>[];
    }

    final List<Alimento> alimentos = dietas
        .expand((d) => d.refeicoes)
        .expand((r) => r.alimentos)
        .cast<Alimento>()
        .toList();

    if (alimentos.isEmpty) {
      final locais = await _localDb.getAlimentosPlano();
      if (locais.isNotEmpty) {
        return locais;
      }
      return <Alimento>[];
    }

    await _localDb.salvarAlimentosPlano(alimentos);
    return alimentos;
  }
}
