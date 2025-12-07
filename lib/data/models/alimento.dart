class Alimento {
  final int id;
  final int? refeicaoId;
  final String nome;
  final String grupoAlimentar;
  final String quantidade;
  final int calorias;
  final double? proteinas;
  final double? gorduras;
  final double? carboidratos;

  Alimento({
    required this.id,
    this.refeicaoId,
    required this.nome,
    this.grupoAlimentar = '',
    this.quantidade = '',
    required this.calorias,
    this.proteinas,
    this.gorduras,
    this.carboidratos,
  });

  factory Alimento.fromJson(Map<String, dynamic> json) {
    return Alimento(
      id: json['alimento_id'] ?? json['id'] ?? 0,
      refeicaoId: json['refeicao_id'],
      nome: json['nome'] ?? '',
      grupoAlimentar: json['grupo_alimentar'] ?? json['grupoAlimentar'] ?? '',
      quantidade: json['quantidade'] ?? json['alimento_quantidade'] ?? '',
      calorias: json['calorias'] ?? 0,
      proteinas: (json['proteinas'] as num?)?.toDouble(),
      gorduras: (json['gorduras'] as num?)?.toDouble(),
      carboidratos: (json['carboidratos'] as num?)?.toDouble(),
    );
  }

  factory Alimento.fromMap(Map<String, dynamic> map) {
    return Alimento(
      id: map['id'] ?? 0,
      refeicaoId: map['refeicao_id'], // pode não existir no SQLite → fica null
      nome: map['nome'] ?? '',
      grupoAlimentar: map['grupo_alimentar'] ?? map['grupoAlimentar'] ?? '',
      quantidade: map['quantidade'] ?? map['alimento_quantidade'] ?? '',
      calorias: map['calorias'] ?? 0,
      proteinas: (map['proteinas'] as num?)?.toDouble(),
      gorduras: (map['gorduras'] as num?)?.toDouble(),
      carboidratos: (map['carboidratos'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alimento_id': id,
      'refeicao_id': refeicaoId,
      'nome': nome,
      'grupo_alimentar': grupoAlimentar,
      'quantidade': quantidade,
      'calorias': calorias,
      'proteinas': proteinas,
      'gorduras': gorduras,
      'carboidratos': carboidratos,
    };
  }
}
