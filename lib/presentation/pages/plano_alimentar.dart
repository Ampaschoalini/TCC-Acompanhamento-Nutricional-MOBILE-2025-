import 'package:flutter/material.dart';
import 'alimentos_plano.dart';
import 'nutricionista.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/dieta.dart';
import '../../data/models/refeicao.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/plano_alimentar_service.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/local_database_service.dart';

// IMPORTS PARA NAVEGAÇÃO VIA MENU LATERAL
import 'relatorios.dart';
import 'perfil.dart';
import 'registro.dart';

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
  // KEY PARA CONTROLAR A ABERTURA DO DRAWER PELO BOTÃO DO APPBAR
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String nomeUsuario = '';
  int pacienteId = 0;

  DateTime dataSelecionada = (DateTime.now().toLocal());
  final PlanoAlimentarService _service = PlanoAlimentarService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  Future<List<Dieta>>? _dietasFuture;

  /// Índice selecionado por tipo (ex.: "Café da Manhã") quando houver >1 registro
  final Map<String, int> _selecionadoPorTipo = {};

  /// Cache de checkboxes por dia (chave do dia -> mapa de chaveDoAlimento -> marcado)
  final Map<String, Map<String, bool>> _checksCache = {};

  /// logs de peso salvos pela tela de Registro (mapa 'yyyy-MM-dd' -> kg)
  Map<String, double> _pesoLogs = {};

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  // Persistência de checkboxes
  String _diaKey(DateTime d) => _keyFormatter.format(_dateOnly(d));

  String _checksKey(DateTime d) {
    final baseDia = _diaKey(d);
    if (pacienteId == 0) return 'checks_$baseDia';
    return 'checks_${pacienteId}_$baseDia';
  }

  String _selIdxKey(DateTime d) {
    final baseDia = _diaKey(d);
    if (pacienteId == 0) return 'selidx_$baseDia';
    return 'selidx_${pacienteId}_$baseDia';
  }


  Future<Map<String, bool>> _loadChecksParaDia(DateTime dia) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _checksKey(dia); // ✅ agora por paciente
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
    final key = _checksKey(dia); // ✅ agora por paciente
    await prefs.setString(key, json.encode(mapa));
  }

  /// Retorna o mapa de checks em memória para o dia (carrega do disco se necessário)
  Future<Map<String, bool>> _getChecksMap(DateTime dia) async {
    final dk = _checksKey(dia);
    if (_checksCache.containsKey(dk)) return _checksCache[dk]!;
    final loaded = await _loadChecksParaDia(dia);
    _checksCache[dk] = loaded;
    return loaded;
  }

  // Persistência da OPÇÃO selecionada por refeição (ex.: opção 1/2/3)

  Future<Map<String, int>> _loadSelecaoParaDia(DateTime dia) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_selIdxKey(dia));
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = json.decode(raw);
      final Map<String, int> map = {};
      decoded.forEach((k, v) {
        int? asInt;
        if (v is int) {
          asInt = v;
        } else {
          try { asInt = int.parse(v.toString()); } catch (_) {}
        }
        if (asInt != null) map[k] = asInt;
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSelecaoParaDia(DateTime dia, Map<String, int> mapa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selIdxKey(dia), json.encode(mapa));
  }

  Future<void> _persistSelecionadoParaDiaAtual(String tipo, int idx) async {
    final atual = await _loadSelecaoParaDia(dataSelecionada);
    atual[tipo] = idx;
    await _saveSelecaoParaDia(dataSelecionada, atual);
  }

  Future<void> _loadSelecaoDoDiaAtual() async {
    final sel = await _loadSelecaoParaDia(dataSelecionada);
    _selecionadoPorTipo
      ..clear()
      ..addAll(sel);
  }

  Future<void> carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString('nome') ?? '';
    final id = prefs.getInt('paciente_id') ?? 0;

    _pesoLogs = _readLogsMap(prefs.getString('logs_peso_$id'));

    setState(() {
      nomeUsuario = nome;
      pacienteId = id;
      _dietasFuture = _service.getDietasByPacienteId(pacienteId);
    });

    // Pré-carrega os checks do dia atual
    await _getChecksMap(dataSelecionada);
    // Restaura as opções selecionadas (ex.: opção 2)
    await _loadSelecaoDoDiaAtual();
    setState(() {});
  }

  // Normalização e UI helpers
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

  // Chaves de alimentos (para persistência por alimento/refeição)
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

  // Cálculo de kcal consumidas (via prefs, não pelo modelo)
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

  Future<void> _atualizarKcalConsumidasNoSQLite() async {
    if (pacienteId == 0) return;
    final future = _dietasFuture;
    if (future == null) return;

    try {
      final dietas = await future;
      if (dietas.isEmpty) return;

      final dataSomenteDia = _dateOnly(dataSelecionada);

      final dietasValidas = dietas.where((dieta) {
        final inicio = dieta.dataInicio;
        final fim = dieta.dataTermino;
        if (inicio == null || fim == null) return false;
        final i = _dateOnly(inicio);
        final f = _dateOnly(fim);
        return !dataSomenteDia.isBefore(i) && !dataSomenteDia.isAfter(f);
      });

      final numKcal = await _caloriasConsumidasDiaViaPrefs(dietasValidas);
      final kcalDia = numKcal.toDouble();

      await _localDb.upsertRegistroDiario(
        pacienteId: pacienteId,
        data: dataSomenteDia,
        kcalDia: kcalDia,
      );
    } catch (_) {
      // Se houver erro ao salvar, apenas ignore para não quebrar a tela
    }
  }


  // DRAWER (MENU LATERAL)
  Drawer _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary, kPrimarySoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Menu',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          nomeUsuario.isEmpty ? 'Bem-vindo(a)' : nomeUsuario,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Itens
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: kPrimary),
              title: const Text('Plano Alimentar'),
              onTap: () {
                Navigator.of(context).pop(); // fecha o drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: kPrimary),
              title: const Text('Registro'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined_rounded, color: kPrimary),
              title: const Text('Relatórios'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RelatoriosPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: kPrimary),
              title: const Text('Alimentos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlimentosPlanoPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: kPrimary),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PerfilPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_information, color: kPrimary),
              title: const Text('Nutricionista'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NutricionistaPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // BLOCO: gráfico com os 7 últimos pesos

  Map<String, double> _readLogsMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> m = jsonDecode(raw);
      return m.map((k, v) {
        final dv = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
        return MapEntry(k, dv);
      });
    } catch (_) {
      return {};
    }
  }

  DateTime? _parseDiaKey(String s) {
    try {
      return _keyFormatter.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Retorna os 7 registros MAIS RECENTES (ordenados por data ASC para desenhar na ordem)
  List<MapEntry<DateTime, double>> _ultimos7PesosOrdenados() {
    final List<MapEntry<DateTime, double>> parsed = [];
    _pesoLogs.forEach((k, v) {
      final d = _parseDiaKey(k);
      if (d != null) parsed.add(MapEntry(d, v));
    });
    if (parsed.isEmpty) return const [];
    parsed.sort((a, b) => b.key.compareTo(a.key)); // DESC (mais recente primeiro)
    final take = parsed.take(7).toList();
    take.sort((a, b) => a.key.compareTo(b.key)); // ASC para exibir da esquerda p/ direita
    return take;
  }

  ({double minY, double maxY}) _rangeYFromValues(List<double> values, {double pad = 0.5}) {
    if (values.isEmpty) return (minY: 0, maxY: 1);
    double minY = values.first, maxY = values.first;
    for (final v in values) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    if (minY == maxY) { minY -= 1; maxY += 1; }
    return (minY: (minY - pad), maxY: (maxY + pad));
  }

  Widget _peso7Widget() {
    final entries = _ultimos7PesosOrdenados();
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: _cardDeco(),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: kPrimary, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Sem registros de peso ainda. Cadastre na aba Registro.',
                style: TextStyle(color: kText, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final labels = entries.map((e) => DateFormat('dd/MM', 'pt_BR').format(e.key)).toList();
    final values = entries.map((e) => e.value).toList();
    final range = _rangeYFromValues(values, pad: 0.4);

    final spots = List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.monitor_weight, color: kPrimary, size: 18),
              SizedBox(width: 6),
              Text('7 Últimos registros de peso', style: TextStyle(fontWeight: FontWeight.w700, color: kText, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: range.minY,
                maxY: range.maxY,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 18,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(labels[idx], style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, m) {
                      return Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                    }),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawHorizontalLine: true, horizontalInterval: null),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    dotData: const FlDotData(show: true),
                    color: kPrimary,
                    barWidth: 2.2, // mais fino
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots.map((it) {
                      final idx = it.x.toInt();
                      final label = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                      return LineTooltipItem('$label\n${it.y.toStringAsFixed(1)} kg', const TextStyle(color: Colors.white, fontSize: 11));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
    border: Border.all(color: const Color(0x11000000)),
  );

  @override
  Widget build(BuildContext context) {
    final dataSomenteDia = _dateOnly(dataSelecionada);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBg,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
      ),
      drawer: _buildAppDrawer(context),

      body: SafeArea(
        child: Column(
          children: [
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Abrir menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
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
                    )
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _peso7Widget(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left_rounded, size: 32, color: kPrimary),
                    onPressed: () async {
                      final nova = dataSelecionada.subtract(const Duration(days: 1));
                      dataSelecionada = nova;
                      await _getChecksMap(nova);
                      await _loadSelecaoDoDiaAtual();
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      await _getChecksMap(nova);
                      await _loadSelecaoDoDiaAtual();
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

                  String? objetivo;
                  try {
                    objetivo = dietasValidas
                        .map((d) => (d.objetivo).toString().trim())
                        .firstWhere((o) => o.isNotEmpty, orElse: () => '');
                    if (objetivo.isEmpty) objetivo = null;
                  } catch (_) {
                    objetivo = null;
                  }

                  // AGRUPAMENTO + DEDUPLICAÇÃO
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
                              const Icon(Icons.flag_rounded, color: kPrimary, size: 18),
                              const SizedBox(height: 0, width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Objetivo da dieta", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                                    const SizedBox(height: 4),
                                    Text(objetivo, style: TextStyle(color: Colors.black.withOpacity(.75), height: 1.3)),
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
                                    Icon(_iconFromTipo(tipo), color: Colors.white, size: 18),
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
                                                return true;
                                              }).toList();

                                              final checks = await _getChecksMap(dataSelecionada);
                                              for (final a in alimentosAnt) {
                                                final key = _alimentoKey(tipo, ridAnt, a);
                                                checks.remove(key);
                                              }
                                              await _saveChecksParaDia(dataSelecionada, checks);
                                            }
                                            setState(() => _selecionadoPorTipo[tipo] = novo ?? 0);
                                            await _persistSelecionadoParaDiaAtual(tipo, novo ?? 0);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              Builder(
                                builder: (_) {
                                  final Map<String, dynamic> sel = items[idxValido];
                                  final Refeicao r = sel['ref'] as Refeicao;
                                  final String horario = (sel['horario'] as String?) ?? '';
                                  final int? rid = sel['rid'] as int?;

                                  final String tituloRef = _normalizeTipo(tipo);
                                  final String subTituloHorario = _horarioCurto(horario);

                                  final List alimentos = (sel['alimentosAcum'] as List?) ?? (r.alimentos as List?) ?? const [];

                                  final List alimentosFiltrados = alimentos.where((a) {
                                    try {
                                      final ridAlim = (a.refeicaoId ?? a.refeicao_id) as int?;
                                      if (rid != null && ridAlim != null) return ridAlim == rid;
                                    } catch (_) {}
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
                                                          await _atualizarKcalConsumidasNoSQLite();

                                                          setState(() {});
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