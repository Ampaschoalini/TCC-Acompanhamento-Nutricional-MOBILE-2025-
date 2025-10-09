import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

// (Opcional) Se você já usa esses modelos/serviço no app, importe-os.
// Com eles, conseguimos ler as kcal dos alimentos do plano para somar as "consumidas".
import '../../data/models/dieta.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/dieta_service.dart';

// === Cores do seu tema (seguindo padrão definido antes) ===
const Color kBg = Color(0xFFF5F5F5);
const Color kPrimary = Color(0xFFEC8800);
const Color kPrimarySoft = Color(0xFFFFB36B);
const Color kText = Color(0xFF444444);

// === API do projeto WEB ===
// Ajuste esta URL conforme o seu backend (ex.: http://10.0.2.2:3000 para emulador Android).
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8800');

// === Filtros de período ===
enum Periodo { dia, semana, mes, ano }

final DateFormat _fmtDia = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _fmtMesAno = DateFormat('MM/yyyy', 'pt_BR');
final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd', 'pt_BR');

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
// === BEGIN: Helpers de normalização e IMC ===

// Converte _altura para METROS: se > 3, assume cm; caso contrário, já está em m.
  double? get _alturaMetros {
    if (_altura == null) return null;
    final a = _altura!;
    return a > 3 ? a / 100.0 : a;
  }

  double? get _alturaCentimetros {
    final aM = _alturaMetros;
    if (aM == null) return null;
    return aM * 100.0;
  }

  String get _pesoFmtKg => _peso == null ? '--' : '${_peso!.toStringAsFixed(1)} kg';
  String get _alturaFmtCm => _alturaCentimetros == null ? '--' : '${_alturaCentimetros!.toStringAsFixed(1)} cm';

  // Recalcula IMC usando altura em METROS normalizada
  double? get _imc {
    if (_peso == null) return null;
    final aM = _alturaMetros;
    if (aM == null || aM == 0) return null;
    return _peso! / (aM * aM);
  }

// === END: Helpers de normalização e IMC ===

  // -------------------- Estado / serviços --------------------
  final DietaService _service = DietaService();
  Future<List<Dieta>>? _dietasFuture;

  Periodo _periodo = Periodo.dia;
  DateTime _baseDate = DateTime.now().toLocal(); // data base do filtro (dia/semana/mês/ano)

  // Preferências do paciente
  double? _peso;     // kg
  double? _altura;   // metros (ou cm normalizado para m)
  double? _cintura;  // cm
  double? _quadril;  // cm
  double? _braco;    // cm
  double? _perna;    // cm

  // Meta (pode vir do nutricionista futuramente)
  int metaKcal = 2000;

  // --- Variáveis de estado para controlar o future do gráfico ---
  Future<List<double>>? _kcalFuture;
  String? _lastKcalFutureKey;

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasEApi();
  }

  Future<void> _carregarPreferenciasEApi() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Carrega valores LOCAIS (fallback) — mantém compatibilidade
    _peso    = (prefs.getDouble('peso') ?? (prefs.getInt('peso')?.toDouble()));
    _altura  = (prefs.getDouble('altura') ?? (prefs.getInt('altura')?.toDouble()));
    _cintura = (prefs.getDouble('med_cintura') ?? (prefs.getInt('med_cintura')?.toDouble()));
    _quadril = (prefs.getDouble('med_quadril') ?? (prefs.getInt('med_quadril')?.toDouble()));
    _braco   = (prefs.getDouble('med_braco') ?? (prefs.getInt('med_braco')?.toDouble()));
    _perna   = (prefs.getDouble('med_perna') ?? (prefs.getInt('med_perna')?.toDouble()));

    final pacienteId = prefs.getInt('paciente_id') ?? 0;
    final token = prefs.getString('token'); // se você usa JWT

    // 2) Chama o serviço do PLANO alimentar
    setState(() {
      _dietasFuture = _service.getDietasByPacienteId(pacienteId);
    });

    // 3) Busca dados ATUAIS do projeto WEB (peso, altura e medidas corporais)
    try {
      await _carregarDadosDoWeb(pacienteId, token);
    } catch (_) {
      // Mantém os valores do fallback (SharedPreferences) se a API falhar
    }
    setState(() {});
  }

  Future<void> _carregarDadosDoWeb(int pacienteId, String? token) async {
    if (pacienteId == 0) return;

    final uri = Uri.parse('$kApiBaseUrl/patient/getPatientById/$pacienteId');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar paciente: ${resp.statusCode}');
    }

    final body = resp.body;
    if (body.isEmpty) return;
    final data = jsonDecode(body);

    // A API pode retornar um objeto ou lista; trate os dois casos
    final Map<String, dynamic> p =
    (data is List && data.isNotEmpty) ? Map<String, dynamic>.from(data.first) : Map<String, dynamic>.from(data as Map);

    // Campos conforme o seu backend (vide updatePatientByIdService e schema):
    // altura, peso, circunferencia_bracos, circunferencia_cintura, circunferencia_quadril, circunferencia_pernas
    final double? pesoApi    = _toDouble(p['peso']);
    final double? alturaApi  = _toDouble(p['altura']);
    final double? bracos     = _toDouble(p['circunferencia_bracos']);
    final double? cintura    = _toDouble(p['circunferencia_cintura']);
    final double? quadril    = _toDouble(p['circunferencia_quadril']);
    final double? pernas     = _toDouble(p['circunferencia_pernas']);

    // Atualiza estado com dados do WEB (se existirem)
    if (pesoApi != null) _peso = pesoApi;
    if (alturaApi != null) _altura = alturaApi;
    if (cintura != null) _cintura = cintura;
    if (quadril != null) _quadril = quadril;
    if (bracos != null) _braco = bracos;
    if (pernas != null) _perna = pernas;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.replaceAll(',', '.'));
      return parsed;
    }
    return null;
  }

  // -------------------- Helpers de data / período --------------------
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _inicioDaSemana(DateTime d) {
    final wd = d.weekday; // 1=Mon ... 7=Sun
    return _dateOnly(d.subtract(Duration(days: wd - 1)));
  }
  DateTime _fimDaSemana(DateTime d) => _inicioDaSemana(d).add(const Duration(days: 6));
  DateTime _inicioDoMes(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _fimDoMes(DateTime d) => DateTime(d.year, d.month + 1, 0);
  DateTime _inicioDoAno(DateTime d) => DateTime(d.year, 1, 1);
  DateTime _fimDoAno(DateTime d) => DateTime(d.year, 12, 31);

  List<DateTime> _datasNoPeriodo(DateTime base, Periodo p) {
    late DateTime ini;
    late DateTime fim;
    switch (p) {
      case Periodo.dia:
        ini = _dateOnly(base);
        fim = _dateOnly(base);
        break;
      case Periodo.semana:
        ini = _inicioDaSemana(base);
        fim = _fimDaSemana(base);
        break;
      case Periodo.mes:
        ini = _inicioDoMes(base);
        fim = _fimDoMes(base);
        break;
      case Periodo.ano:
        ini = _inicioDoAno(base);
        fim = _fimDoAno(base);
        break;
    }
    final List<DateTime> lst = [];
    for (DateTime d = ini; !d.isAfter(fim); d = d.add(const Duration(days: 1))) {
      lst.add(d);
    }
    return lst;
  }

  // -------------------- Chaves / normalização iguais à tela do Plano --------------------
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

  Future<Map<String, bool>> _loadChecksParaDia(DateTime dia) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'checks_${_keyFormatter.format(_dateOnly(dia))}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = Map<String, dynamic>.from(await Future.value(jsonDecode(raw)));
      return decoded.map((k, v) => MapEntry(k, (v == true)));
    } catch (_) {
      return {};
    }
  }

  // Soma kcal do dia com base no plano alimentar + checkboxes marcados
  Future<double> _kcalConsumidasNoDia(DateTime dia, List<Dieta> dietas) async {
    final checks = await _loadChecksParaDia(dia);
    double total = 0;

    // Filtra dietas válidas para o dia
    final validas = dietas.where((d) {
      final i = d.dataInicio;
      final f = d.dataTermino;
      if (i == null || f == null) return false;
      final di = _dateOnly(i);
      final df = _dateOnly(f);
      final d0 = _dateOnly(dia);
      return !d0.isBefore(di) && !d0.isAfter(df);
    });
    for (final d in validas) {
      for (final r in d.refeicoes) {
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
          if (checks[key] == true) total += kcal.toDouble();
        }
      }
    }
    return total;
  }

  // ---- IMC ----
  String get _imcCategoria {
    final v = _imc;
    if (v == null) return 'Sem dados suficientes';
    if (v < 18.5) return 'Abaixo do peso';
    if (v < 25) return 'Peso normal';
    if (v < 30) return 'Sobrepeso';
    if (v < 35) return 'Obesidade grau I';
    if (v < 40) return 'Obesidade grau II';
    return 'Obesidade grau III';
  }

  Color get _imcCor {
    final v = _imc;
    if (v == null) return Colors.grey;
    if (v < 18.5) return Colors.blueGrey;
    if (v < 25) return Colors.green;
    if (v < 30) return Colors.orange;
    if (v < 35) return Colors.deepOrange;
    if (v < 40) return Colors.redAccent;
    return Colors.red;
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: const Text('Relatórios', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Dieta>>(
          future: _dietasFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(kPrimary)));
            }
            if (snap.hasError) {
              return Center(child: Text('Erro ao carregar dados: ${snap.error}'));
            }

            final dietas = snap.data ?? const <Dieta>[];
            final datas = _datasNoPeriodo(_baseDate, _periodo);

            // --- Lógica para criar/reutilizar o future do gráfico ---
            final kcalFutureKey = "${_baseDate.toIso8601String()}-${_periodo.index}";
            if (kcalFutureKey != _lastKcalFutureKey) {
              _lastKcalFutureKey = kcalFutureKey;
              _kcalFuture = () async {
                final List<double> valores = [];
                for (final d in datas) {
                  valores.add(await _kcalConsumidasNoDia(d, dietas));
                }
                return valores;
              }();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // -------------------- Filtro de período --------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
                    border: Border.all(color: const Color(0x11000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Período', style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chipPeriodo('Data', Periodo.dia),
                          _chipPeriodo('Semana', Periodo.semana),
                          _chipPeriodo('Mês', Periodo.mes),
                          _chipPeriodo('Ano', Periodo.ano),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.date_range, color: kPrimary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_labelPeriodo(), style: const TextStyle(fontWeight: FontWeight.w600))),
                          TextButton.icon(
                            onPressed: _pickPeriodoDate,
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Alterar'),
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // -------------------- Peso / Altura lado a lado --------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
                    border: Border.all(color: const Color(0x11000000)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Peso (kg)',
                          value: _pesoFmtKg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statTile(
                          icon: Icons.height,
                          title: 'Altura (cm)',
                          value: _alturaFmtCm,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // -------------------- IMC (valor + categoria) --------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
                    border: Border.all(color: const Color(0x11000000)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _imcCor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _imcCor.withOpacity(.35)),
                        ),
                        child: const Icon(Icons.favorite, color: kPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IMC', style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
                            const SizedBox(height: 6),
                            Text(_imc == null ? '--' : _imc!.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
                            const SizedBox(height: 4),
                            Text(_imcCategoria,
                                style: TextStyle(color: _imcCor, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // -------------------- Medidas corporais --------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
                    border: Border.all(color: const Color(0x11000000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Medidas corporais', style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _medidaCard(Icons.straighten, 'Cintura', _cm(_cintura))),
                          const SizedBox(width: 10),
                          Expanded(child: _medidaCard(Icons.accessibility_new, 'Quadril', _cm(_quadril))),
                          const SizedBox(width: 10),
                          Expanded(child: _medidaCard(Icons.fitness_center, 'Braço', _cm(_braco))),
                          const SizedBox(width: 10),
                          Expanded(child: _medidaCard(Icons.directions_walk, 'Perna', _cm(_perna))),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // -------------------- Gráfico de Kcal consumidas --------------------
                FutureBuilder<List<double>>(
                  future: _kcalFuture,
                  builder: (context, kcalSnap) {
                    if (kcalSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(kPrimary)),
                        ),
                      );
                    }
                    if (!kcalSnap.hasData || kcalSnap.hasError) {
                      return const Center(child: Text('Não foi possível carregar os dados do gráfico.'));
                    }

                    final valores = kcalSnap.data!;
                    final maxY = (valores.isEmpty ? 0 : (valores.reduce(math.max)));
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,4))],
                        border: Border.all(color: const Color(0x11000000)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kcal consumidas', style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 220,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: (maxY > metaKcal ? maxY : metaKcal).toDouble(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx < 0 || idx >= datas.length) return const SizedBox.shrink();
                                        final d = datas[idx];
                                        return Text(
                                          _periodo == Periodo.ano
                                              ? DateFormat('MM', 'pt_BR').format(d)
                                              : DateFormat('dd', 'pt_BR').format(d),
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                      interval: 1,
                                      reservedSize: 24,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, interval: 500, reservedSize: 32),
                                  ),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true, drawHorizontalLine: true, horizontalInterval: 500),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      for (int i = 0; i < valores.length; i++)
                                        FlSpot(i.toDouble(), valores[i].toDouble()),
                                    ],
                                    isCurved: true,
                                    dotData: const FlDotData(show: true),
                                    color: kPrimary,
                                    barWidth: 3,
                                  ),
                                ],
                                // Linha da meta
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: metaKcal.toDouble(),
                                      color: Colors.redAccent,
                                      strokeWidth: 1.5,
                                      dashArray: [6, 3],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.topLeft,
                                        labelResolver: (_) => 'Meta ${metaKcal}kcal',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // -------------------- Widgets auxiliares --------------------
  Widget _chipPeriodo(String label, Periodo p) {
    final selected = _periodo == p;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _periodo = p),
      selectedColor: kPrimarySoft,
      labelStyle: TextStyle(color: selected ? Colors.white : kText, fontWeight: FontWeight.w600),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0x11000000)),
    );
  }

  String _labelPeriodo() {
    switch (_periodo) {
      case Periodo.dia:
        return _fmtDia.format(_baseDate);
      case Periodo.semana:
        final ini = _inicioDaSemana(_baseDate);
        final fim = _fimDaSemana(_baseDate);
        return '${_fmtDia.format(ini)} a ${_fmtDia.format(fim)}';
      case Periodo.mes:
        return _fmtMesAno.format(_baseDate);
      case Periodo.ano:
        return _baseDate.year.toString();
    }
  }

  Future<void> _pickPeriodoDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _baseDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecione uma data base',
      confirmText: 'OK',
      cancelText: 'Cancelar',
    );
    if (picked != null) setState(() => _baseDate = picked);
  }

  Widget _statTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPrimary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: kText)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _medidaCard(IconData icon, String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0,2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: kPrimary),
          const SizedBox(height: 6),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kText)),
        ],
      ),
    );
  }

  String _cm(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)} cm';
}
