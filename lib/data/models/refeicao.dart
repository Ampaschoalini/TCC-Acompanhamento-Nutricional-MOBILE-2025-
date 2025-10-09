import 'alimento.dart';

class Refeicao {
  /// IDs opcionais para compatibilidade com o backend
  final int? id;           // refeicao_id
  final int? dietaId;      // dieta_id

  /// Rótulo da refeição (ex.: "Café da manhã", "Almoço", ...)
  final String tipoRefeicao;

  /// Horário no formato vindo do backend (ex.: "08:00:00")
  final String horario;

  /// Timestamp opcional
  final DateTime? createdAt;

  /// Lista de alimentos
  final List<Alimento> alimentos;

  Refeicao({
    this.id,
    this.dietaId,
    required this.tipoRefeicao,
    required this.horario,
    this.createdAt,
    required this.alimentos,
  });

  /// Normaliza o tipo para rótulos consistentes usados na UI
  String get tipoRefeicaoNormalizado {
    final v = tipoRefeicao.trim().toLowerCase();
    if (v.contains('café') || v.contains('manhã') || v.contains('manha')) return 'Café da Manhã';
    if (v.contains('almo')) return 'Almoço';
    if (v.contains('jantar')) return 'Jantar';
    if (v.contains('lanche da tarde')) return 'Lanche da Tarde';
    if (v.contains('lanche')) return 'Lanche';
    if (v.contains('ceia')) return 'Ceia';
    return tipoRefeicao.trim().isEmpty ? 'Outros' : tipoRefeicao.trim();
  }

  /// Retorna horário "curto" (HH:mm) mesmo que venha "HH:mm:ss"
  String get horarioCurto {
    final h = horario.trim();
    if (h.length >= 5) return h.substring(0, 5);
    return h;
  }

  factory Refeicao.fromJson(Map<String, dynamic> json) {
    // Aceita chaves snake_case e camelCase
    final rawTipo = (json['tipoRefeicao'] ?? json['tipo_refeicao'] ?? '').toString();
    final rawHorario = (json['horario'] ?? json['hora'] ?? '').toString();

    DateTime? created;
    final rawCreated = (json['createdAt'] ?? json['created_at']);
    if (rawCreated is String && rawCreated.isNotEmpty) {
      try { created = DateTime.parse(rawCreated); } catch (_) {}
    }

    final alimentosList = (json['alimentos'] as List<dynamic>?) ?? const [];
    return Refeicao(
      id: (json['refeicao_id'] ?? json['id']) is int
          ? (json['refeicao_id'] ?? json['id']) as int
          : int.tryParse((json['refeicao_id'] ?? json['id'] ?? '').toString()),
      dietaId: (json['dieta_id'] ?? json['dietaId']) is int
          ? (json['dieta_id'] ?? json['dietaId']) as int
          : int.tryParse((json['dieta_id'] ?? json['dietaId'] ?? '').toString()),
      tipoRefeicao: rawTipo,
      horario: rawHorario,
      createdAt: created,
      alimentos: alimentosList.map((e) => Alimento.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Exporta em snake_case por compatibilidade com o backend
      'refeicao_id': id,
      'dieta_id': dietaId,
      'tipo_refeicao': tipoRefeicao,
      'horario': horario,
      'created_at': createdAt?.toIso8601String(),
      'alimentos': alimentos.map((a) => a.toJson()).toList(),
    };
  }
}
