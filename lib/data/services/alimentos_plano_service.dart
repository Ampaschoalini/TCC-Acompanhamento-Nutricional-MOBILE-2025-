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

    // compatível com versões que retornam lista ou um único enum
    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  /// Busca os alimentos do plano do paciente, com fallback para SQLite.
  Future<List<Alimento>> getAlimentosPlanoByPaciente(int pacienteId) async {
    final offline = await _isOffline();

    // 1) Sem conexão → usa só o cache local
    if (offline) {
      return _localDb.getAlimentosPlano();
    }

    List<Dieta> dietas;

    // 2) Com conexão → tenta API
    try {
      dietas = await _remote.getDietasByPacienteId(pacienteId);
    } catch (e) {
      // Em teoria, o DietaService já está protegendo, mas deixo aqui por segurança
      final locais = await _localDb.getAlimentosPlano();
      if (locais.isNotEmpty) return locais;
      return <Alimento>[];
    }

    // Achata Dieta -> Refeições -> Alimentos
    final alimentos = dietas
        .expand((d) => d.refeicoes)
        .expand((r) => r.alimentos)
        .toList();

    // 3) Se a API devolveu vazio, preferimos o cache (se existir)
    if (alimentos.isEmpty) {
      final locais = await _localDb.getAlimentosPlano();
      if (locais.isNotEmpty) {
        return locais;
      }
      // Sem cache também → nada pra mostrar
      return <Alimento>[];
    }

    // 4) API trouxe dados válidos → atualiza cache e retorna
    await _localDb.salvarAlimentosPlano(alimentos);
    return alimentos;
  }
}
