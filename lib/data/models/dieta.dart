import 'refeicao.dart';

class Dieta {
  final int id;
  final String nome;
  final String objetivo;
  final DateTime? dataInicio;
  final DateTime? dataTermino;
  final List<Refeicao> refeicoes;

  /// Novo campo para identificar o tipo da refeição (Café da Manhã, Almoço, etc.)
  final String tipoRefeicao;

  Dieta({
    required this.id,
    required this.nome,
    required this.objetivo,
    this.dataInicio,
    this.dataTermino,
    required this.refeicoes,
    this.tipoRefeicao = "Outros", // valor padrão
  });

  factory Dieta.fromJson(Map<String, dynamic> json) {
    return Dieta(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      objetivo: json['objetivo'] ?? '',
      dataInicio: (json['dataInicio'] ?? json['data_inicio']) != null &&
          (json['dataInicio'] ?? json['data_inicio']) != ''
          ? DateTime.parse(json['dataInicio'] ?? json['data_inicio'])
          : null,
      dataTermino: (json['dataTermino'] ?? json['data_termino']) != null &&
          (json['dataTermino'] ?? json['data_termino']) != ''
          ? DateTime.parse(json['dataTermino'] ?? json['data_termino'])
          : null,
      refeicoes: (json['refeicoes'] as List<dynamic>?)
          ?.map((e) => Refeicao.fromJson(e))
          .toList() ??
          [],
      tipoRefeicao: json['tipoRefeicao'] ??
          json['tipo_refeicao'] ??
          "Outros", // pega do backend se vier
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'objetivo': objetivo,
      'dataInicio': dataInicio?.toIso8601String(),
      'dataTermino': dataTermino?.toIso8601String(),
      'refeicoes': refeicoes.map((e) => e.toJson()).toList(),
      'tipoRefeicao': tipoRefeicao,
    };
  }
}
