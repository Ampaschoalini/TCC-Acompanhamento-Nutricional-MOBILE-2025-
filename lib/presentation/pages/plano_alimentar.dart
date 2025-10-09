
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../data/models/dieta.dart';
import '../../data/models/refeicao.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/dieta_service.dart';

const Color kBg = Color(0xFFF5F5F5);
const Color kPrimary = Color(0xFFEC8800);
const Color kPrimarySoft = Color(0xFFFFB36B);
const Color kText = Color(0xFF444444);

final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd', 'pt_BR');

class PlanoAlimentarPage extends StatefulWidget {
  const PlanoAlimentarPage({super.key});

  @override
  State<PlanoAlimentarPage> createState() => _PlanoAlimentarPageState();
}

class _PlanoAlimentarPageState extends State<PlanoAlimentarPage> {
  String nomeUsuario = '';
  int pacienteId = 0;

  DateTime dataSelecionada = DateTime.now();
  final DietaService _service = DietaService();
  Future<List<Dieta>>? _dietasFuture;

  /// Índice selecionado por tipo (ex.: "Café da Manhã") quando houver >1 registro
  final Map<String, int> _selecionadoPorTipo = {};

  /// Cache de checkboxes por dia (chave do dia -> mapa de chaveDoAlimento -> marcado)
  final Map<String, Map<String, bool>> _checksCache = {};

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  // -----------------------------
  // Persistência de checkboxes
  // -----------------------------
  String _diaKey(DateTime d) => _keyFormatter.format(_dateOnly(d));

  Future<Map<String, bool>> _loadChecksParaDia(DateTime dia) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'checks_${_diaKey(dia)}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v == true)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveChecksParaDia(DateTime dia, Map<String, bool> mapa) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'checks_${_diaKey(dia)}';
    await prefs.setString(key, json.encode(mapa));
  }

  /// Retorna o mapa de checks em memória para o dia (carrega do disco se necessário)
  Future<Map<String, bool>> _getChecksMap(DateTime dia) async {
    final dk = _diaKey(dia);
    if (_checksCache.containsKey(dk)) return _checksCache[dk]!;
    final loaded = await _loadChecksParaDia(dia);
    _checksCache[dk] = loaded;
    return loaded;
  }

  Future<void> carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString('nome') ?? '';
    final id = prefs.getInt('paciente_id') ?? 0;

    setState(() {
      nomeUsuario = nome;
      pacienteId = id;
      _dietasFuture = _service.getDietasByPacienteId(pacienteId);
    });

    // Pré-carrega os checks do dia atual
    await _getChecksMap(dataSelecionada);
    setState(() {});
  }

  // -----------------------------
  // Normalização e UI helpers
  // -----------------------------
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _normalizeTipo(String raw) {
    final v = raw.trim().toLowerCase();

    if (v.contains('lanche') && (v.contains('manhã') || v.contains('manha'))) return 'Lanche da manhã';
    if (v.contains('lanche') && v.contains('tarde')) return 'Lanche da tarde';

    if (v.contains('café')) return 'Café da Manhã';
    if (v.contains('almo')) return 'Almoço';
    if (v.contains('jantar')) return 'Jantar';
    if (v.contains('lanche')) return 'Lanche';
    if (v.contains('ceia')) return 'Ceia';

    return raw.trim().isEmpty ? 'Outros' : raw.trim();
  }

  /// Apenas para o rótulo do dropdown (pedido do usuário: "Café da manhã 1/2")
  String _dropdownTipoLabel(String tipoNormalizado) {
    if (tipoNormalizado == 'Café da Manhã') return 'Café da manhã';
    return tipoNormalizado;
  }

  IconData _iconFromTipo(String tipo) {
    final v = tipo.toLowerCase();

    if (v.contains('café') || ((v.contains('manhã') || v.contains('manha')) && !v.contains('lanche'))) {
      return Icons.free_breakfast;
    }
    if (v.contains('almoço') || v.contains('almoco')) return Icons.lunch_dining;
    if (v.contains('jantar')) return Icons.dinner_dining;
    if (v.contains('lanche') && (v.contains('manhã') || v.contains('manha'))) return Icons.free_breakfast;
    if (v.contains('lanche') && v.contains('tarde')) return Icons.cookie;
    if (v.contains('lanche')) return Icons.fastfood;
    if (v.contains('ceia')) return Icons.nightlife;
    return Icons.fastfood;
  }

  LinearGradient _gradientFromTipo(String tipo) {
    final v = tipo.toLowerCase();

    if (v.contains('café')) {
      return const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    if (v.contains('lanche') && (v.contains('manhã') || v.contains('manha'))) {
      return const LinearGradient(colors: [Color(0xFF03A9F4), Color(0xFF64B5F6)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    if (v.contains('almoço')) {
      return const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    if (v.contains('lanche') && v.contains('tarde')) {
      return const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    if (v.contains('jantar')) {
      return const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFE57373)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    if (v.contains('ceia')) {
      return const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF90A4AE)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
    return const LinearGradient(colors: [kPrimary, kPrimarySoft], begin: Alignment.centerLeft, end: Alignment.centerRight);
  }

  String _horarioCurto(String horario) {
    final h = horario.trim();
    if (h.isEmpty) return '';
    final parts = h.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return h;
  }

  int _minutosDoDia(String horario) {
    try {
      final p = horario.split(':');
      final h = int.parse(p[0]);
      final m = p.length > 1 ? int.parse(p[1]) : 0;
      return h * 60 + m;
    } catch (_) {
      return 24 * 60;
    }
  }

  // -----------------------------
  // Chaves de alimentos (para persistência por alimento/refeição)
  // -----------------------------
  String _alimentoKey(String tipo, int? refeicaoId, dynamic alimento) {
    int? aid;
    try { aid = (alimento.id as int?); } catch (_) {}
    if (aid == null) { try { aid = (alimento.alimentoId as int?); } catch (_) {} }
    if (aid == null) { try { aid = (alimento.alimento_id as int?); } catch (_) {} }

    String nome = '';
    try { nome = (alimento.nome ?? '').toString(); } catch (_) {}

    final t = _normalizeTipo(tipo);
    final rid = refeicaoId?.toString() ?? '0';
    final a = aid?.toString() ?? '';
    return 't:$t|r:$rid|a:$a|n:$nome';
  }

  // -----------------------------
  // Cálculo de kcal consumidas (via prefs, não pelo modelo)
  // -----------------------------
  Future<num> _caloriasConsumidasDiaViaPrefs(Iterable<Dieta> dietas) async {
    num total = 0;
    final checks = await _getChecksMap(dataSelecionada);

    for (final d in dietas) {
      for (final r in d.refeicoes) {
        // tipo/horário/id
        final String tipo = () {
          try { return _normalizeTipo((r.tipoRefeicao).toString()); } catch (_) {}
          try { final dyn = r as dynamic; return _normalizeTipo((dyn.tipo_refeicao ?? '').toString()); } catch (_) {}
          return 'Outros';
        }();

        final int? rid = () {
          try { return (r.id as int?); } catch (_) {}
          try { final dyn = r as dynamic; return (dyn.refeicao_id as int?); } catch (_) {}
          return null;
        }();

        final List alimentos = (r.alimentos as List?) ?? const [];
        for (final a in alimentos) {
          num? kcal;
          try { kcal = (a.calorias ?? a.kcal) as num?; } catch (_) {}
          if (kcal == null) continue;

          final key = _alimentoKey(tipo, rid, a);
          if (checks[key] == true) total += kcal;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dataSomenteDia = _dateOnly(dataSelecionada); // comparação inclusiva
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kPrimarySoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 26, backgroundImage: AssetImage('assets/images/logo.png'), backgroundColor: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          "Olá, ${nomeUsuario.isEmpty ? 'bem-vindo(a)' : nomeUsuario}!",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: .2),
                        ),
                        const SizedBox(height: 4),
                        Text("Aqui está seu plano alimentar", style: TextStyle(color: Colors.white.withOpacity(0.9))),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            // Barra de data à esquerda + kcal consumidas à direita
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left_rounded, size: 32, color: kPrimary),
                    onPressed: () async {
                      final nova = dataSelecionada.subtract(const Duration(days: 1));
                      dataSelecionada = nova;
                      await _getChecksMap(nova); // pré-carrega checks
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_dateFormatter.format(dataSomenteDia),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                    ),
                  ),
                  FutureBuilder<List<Dieta>>(
                    future: _dietasFuture,
                    builder: (context, snapshot) {
                      return FutureBuilder<num>(
                        future: () async {
                          num kcalDia = 0;
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final dietasValidas = snapshot.data!.where((dieta) {
                              final inicio = dieta.dataInicio;
                              final fim = dieta.dataTermino;
                              if (inicio == null || fim == null) return false;
                              final i = _dateOnly(inicio);
                              final f = _dateOnly(fim);
                              return !dataSomenteDia.isBefore(i) && !dataSomenteDia.isAfter(f);
                            });
                            kcalDia = await _caloriasConsumidasDiaViaPrefs(dietasValidas);
                          }
                          return kcalDia;
                        }(),
                        builder: (context, kcalSnap) {
                          final kcalDia = (kcalSnap.data ?? 0).toDouble();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2))],
                              border: Border.all(color: const Color(0x11000000)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: kPrimary, size: 18),
                                const SizedBox(width: 6),
                                Text('${kcalDia.toStringAsFixed(0)} kcal', style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right_rounded, size: 32, color: kPrimary),
                    onPressed: () async {
                      final nova = dataSelecionada.add(const Duration(days: 1));
                      dataSelecionada = nova;
                      await _getChecksMap(nova); // pré-carrega checks
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: _dietasFuture == null
                  ? const _Carregando()
                  : FutureBuilder<List<Dieta>>(
                future: _dietasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const _Carregando();
                  if (snapshot.hasError) {
                    return _EstadoMensagem(icon: Icons.error_outline_rounded, title: "Algo deu errado", message: "Erro ao carregar o plano: ${snapshot.error}");
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const _EstadoMensagem(icon: Icons.restaurant_rounded, title: "Sem planos encontrados", message: "Você ainda não possui um plano alimentar cadastrado.");
                  }

                  final dietasValidas = snapshot.data!.where((dieta) {
                    final inicio = dieta.dataInicio;
                    final fim = dieta.dataTermino;
                    if (inicio == null || fim == null) return false;
                    final i = _dateOnly(inicio);
                    final f = _dateOnly(fim);
                    return !dataSomenteDia.isBefore(i) && !dataSomenteDia.isAfter(f);
                  }).toList();

                  if (dietasValidas.isEmpty) {
                    return const _EstadoMensagem(icon: Icons.calendar_today, title: "Sem plano nesse dia", message: "Não há plano alimentar para a data selecionada.");
                  }

                  // Objetivo da dieta (se houver)
                  String? objetivo;
                  try {
                    objetivo = dietasValidas
                        .map((d) => (d.objetivo ?? '').toString().trim())
                        .firstWhere((o) => o.isNotEmpty, orElse: () => '');
                    if (objetivo!.isEmpty) objetivo = null;
                  } catch (_) {
                    objetivo = null;
                  }

                  // -------------------------
                  // AGRUPAMENTO + DEDUPLICAÇÃO
                  // -------------------------
                  final Map<String, Map<String, Map<String, dynamic>>> gruposDedup = {};

                  String tipoFromRefeicao(Refeicao r) {
                    try {
                      final raw = (r.tipoRefeicao).toString();
                      return _normalizeTipo(raw);
                    } catch (_) {
                      try {
                        final dyn = r as dynamic;
                        final raw2 = (dyn.tipo_refeicao ?? '').toString();
                        return _normalizeTipo(raw2);
                      } catch (_) {
                        return 'Outros';
                      }
                    }
                  }

                  String horarioFromRefeicao(Refeicao r) {
                    try {
                      return (r.horario).toString();
                    } catch (_) {
                      try {
                        final dyn = r as dynamic;
                        return (dyn.horario ?? '').toString();
                      } catch (_) {
                        return '';
                      }
                    }
                  }

                  int? idFromRefeicao(Refeicao r) {
                    try {
                      return (r.id as int?);
                    } catch (_) {
                      try {
                        final dyn = r as dynamic;
                        return (dyn.refeicao_id as int?);
                      } catch (_) {
                        return null;
                      }
                    }
                  }

                  for (final d in dietasValidas) {
                    for (final r in d.refeicoes) {
                      final tipo = tipoFromRefeicao(r);
                      final horario = horarioFromRefeicao(r);
                      final rid = idFromRefeicao(r);
                      final key = (rid != null) ? 'rid:$rid' : 'k:${tipo}|${horario}';

                      gruposDedup.putIfAbsent(tipo, () => {});
                      final bucket = gruposDedup[tipo]!;

                      if (!bucket.containsKey(key)) {
                        bucket[key] = {
                          'ref': r,
                          'dieta': d,
                          'horario': horario,
                          'rid': rid,
                          'alimentosAcum': <dynamic>[],
                        };
                      }
                      final List<dynamic> acc = bucket[key]!['alimentosAcum'] as List<dynamic>;
                      final List<dynamic> atual = (r.alimentos as List?) ?? const [];
                      acc.addAll(atual);
                    }
                  }

                  // Converte para a estrutura antiga para o restante do fluxo
                  final Map<String, List<Map<String, dynamic>>> grupos = {};
                  gruposDedup.forEach((tipo, mapa) {
                    grupos[tipo] = mapa.values.toList();
                  });

                  final ordemTipos = ['Café da Manhã', 'Lanche da manhã', 'Almoço', 'Lanche da tarde', 'Jantar', 'Ceia', 'Lanche', 'Outros'];

                  final entriesOrdenadas = grupos.entries.toList()
                    ..sort((a, b) {
                      final ai = ordemTipos.indexOf(a.key);
                      final bi = ordemTipos.indexOf(b.key);
                      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
                    });

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (objetivo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
                            border: Border.all(color: const Color(0x11000000)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.flag_rounded, color: kPrimary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Objetivo da dieta", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                                    const SizedBox(height: 4),
                                    Text(objetivo!, style: TextStyle(color: Colors.black.withOpacity(.75), height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ...entriesOrdenadas.map((entry) {
                        final tipo = entry.key;
                        final items = entry.value;

                        // Ordena as refeições do mesmo tipo pelo horário
                        items.sort((a, b) => _minutosDoDia((a['horario'] as String?) ?? '').compareTo(_minutosDoDia((b['horario'] as String?) ?? '')));

                        final idxSelecionado = _selecionadoPorTipo[tipo] ?? 0;
                        final idxValido = idxSelecionado.clamp(0, items.length - 1);
                        _selecionadoPorTipo[tipo] = idxValido;

                        // rótulo do dropdown
                        final dropBase = _dropdownTipoLabel(tipo);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
                            border: Border.all(color: const Color(0x11000000)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: _gradientFromTipo(tipo),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_iconFromTipo(tipo), color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tipo,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (items.length > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(.18),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: DropdownButton<int>(
                                          value: idxValido,
                                          underline: const SizedBox.shrink(),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                          dropdownColor: Colors.white,
                                          style: const TextStyle(color: kText),
                                          items: List.generate(items.length, (i) {
                                            final label = '$dropBase ${i + 1}';
                                            return DropdownMenuItem<int>(value: i, child: Text(label));
                                          }),
                                          onChanged: (novo) async {
                                            // Ao trocar de opção de refeição, desmarca TODOS os checks da opção ANTERIOR, usando a mesma lista renderizada.
                                            final antigo = _selecionadoPorTipo[tipo] ?? 0;
                                            if (antigo >= 0 && antigo < items.length) {
                                              final Map<String, dynamic> anterior = items[antigo];
                                              final Refeicao rAnt = anterior['ref'] as Refeicao;
                                              final int? ridAnt = () {
                                                try { return (rAnt.id as int?); } catch (_) {}
                                                try { final dyn = rAnt as dynamic; return (dyn.refeicao_id as int?); } catch (_) {}
                                                return null;
                                              }();

                                              // Usa a MESMA base de dados dos cards (alimentosAcum) e aplica o mesmo filtro por refeicao_id
                                              final List alimentosBase = (anterior['alimentosAcum'] as List?) ?? (rAnt.alimentos as List?) ?? const [];
                                              final List alimentosAnt = alimentosBase.where((a) {
                                                try {
                                                  final ridAlim = (a.refeicaoId ?? a.refeicao_id) as int?;
                                                  if (ridAnt != null && ridAlim != null) return ridAlim == ridAnt;
                                                } catch (_) {}
                                                return true; // se não houver campo, mantém
                                              }).toList();

                                              final checks = await _getChecksMap(dataSelecionada);
                                              for (final a in alimentosAnt) {
                                                final key = _alimentoKey(tipo, ridAnt, a);
                                                checks.remove(key);
                                              }
                                              await _saveChecksParaDia(dataSelecionada, checks);
                                            }
                                            setState(() => _selecionadoPorTipo[tipo] = novo ?? 0);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Conteúdo: apenas a refeição selecionada (ou única)
                              Builder(
                                builder: (_) {
                                  final Map<String, dynamic> sel = items[idxValido];
                                  final Refeicao r = sel['ref'] as Refeicao;
                                  final String horario = (sel['horario'] as String?) ?? '';
                                  final int? rid = sel['rid'] as int?;

                                  final String tituloRef = _normalizeTipo(tipo);
                                  final String subTituloHorario = _horarioCurto(horario);

                                  // Usa a lista acumulada (deduplicada); se não houver, cai para r.alimentos
                                  final List alimentos = (sel['alimentosAcum'] as List?) ?? (r.alimentos as List?) ?? const [];

                                  // --- FILTRO POR refeicao_id QUANDO DISPONÍVEL ---
                                  final List alimentosFiltrados = alimentos.where((a) {
                                    try {
                                      final ridAlim = (a.refeicaoId ?? a.refeicao_id) as int?;
                                      if (rid != null && ridAlim != null) return ridAlim == rid;
                                    } catch (_) {}
                                    // Se não houver a coluna no model, exibe normalmente
                                    return true;
                                  }).toList();

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0x0F000000)),
                                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    subTituloHorario.isEmpty ? tituloRef : '$tituloRef • $subTituloHorario',
                                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (alimentosFiltrados.isEmpty)
                                              Text('Sem alimentos cadastrados para esta refeição.', style: TextStyle(color: Colors.black.withOpacity(.6))),
                                            FutureBuilder<Map<String, bool>>(
                                              future: _getChecksMap(dataSelecionada),
                                              builder: (context, checksSnap) {
                                                final checks = checksSnap.data ?? {};
                                                return Column(
                                                  children: [
                                                    ...alimentosFiltrados.map((a) {
                                                      String nomeAlim = '';
                                                      num? kcal;
                                                      String qtdStr = '';

                                                      try { nomeAlim = (a.nome ?? '').toString(); } catch (_) {}
                                                      try { kcal = (a.calorias ?? a.kcal) as num?; } catch (_) {}
                                                      try { qtdStr = (a.quantidade ?? a.alimento_quantidade ?? '').toString(); } catch (_) {}

                                                      final key = _alimentoKey(tipo, rid, a);
                                                      final bool marcado = checks[key] == true;

                                                      // Subtítulo com qtd + kcal
                                                      final List<String> subparts = [];
                                                      if (qtdStr.isNotEmpty) subparts.add(qtdStr);
                                                      if (kcal != null) subparts.add('${kcal.toStringAsFixed(0)} kcal');
                                                      final String? subtitleStr = subparts.isEmpty ? null : subparts.join(' • ');

                                                      return CheckboxListTile(
                                                        contentPadding: EdgeInsets.zero,
                                                        dense: true,
                                                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                                        title: Text(nomeAlim.isEmpty ? 'Alimento' : nomeAlim, style: const TextStyle(fontSize: 14, color: kText)),
                                                        subtitle: (subtitleStr == null) ? null : Text(subtitleStr, style: TextStyle(color: Colors.black.withOpacity(.6))),
                                                        value: marcado,
                                                        onChanged: (v) async {
                                                          final mapa = await _getChecksMap(dataSelecionada);
                                                          if (v == true) {
                                                            mapa[key] = true;
                                                          } else {
                                                            mapa.remove(key);
                                                          }
                                                          await _saveChecksParaDia(dataSelecionada, mapa);
                                                          setState(() {}); // reconta kcal do topo
                                                        },
                                                        activeColor: kPrimary,
                                                        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                      );
                                                    }).toList(),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: 42,
        width: 42,
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
          backgroundColor: Color(0x33EC8800),
          strokeWidth: 4,
        ),
      ),
    );
  }
}

class _EstadoMensagem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EstadoMensagem({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: kPrimary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: Colors.black.withOpacity(.65), height: 1.3),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}