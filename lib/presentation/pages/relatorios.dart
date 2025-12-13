import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/local_database_service.dart';

// === Modelos e serviço para ler dietas e calcular kcal por dia ===
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/plano_alimentar_service.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/models/dieta.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/models/refeicao.dart';

// === Cores do tema ===
const Color kBg = Color(0xFFF5F5F5);
const Color kPrimary = Color(0xFFEC8800);
const Color kPrimarySoft = Color(0xFFFFB36B);
const Color kText = Color(0xFF444444);

// === API do projeto WEB ===
const String kApiBaseUrl =
String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8800');

const List<String> kGetByIdPathVariants = [
  '/patient/getPatientById/{id}',
  '/patient/{id}',
  '/patients/{id}',
  '/api/patient/{id}',
  '/api/patient/getPatientById/{id}',
];

// === Filtros de período ===
enum Periodo { dia, semana, mes, ano }

// Medidas exibidas em gráfico
enum MedidaKind { cintura, quadril, braco, perna }

final DateFormat _fmtDia = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _fmtMesAno = DateFormat('MM/yyyy', 'pt_BR');
final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd', 'pt_BR');

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  double? get _alturaMetros {
    if (_altura == null) return null;
    final a = _altura!;
    return a > 3 ? a / 100.0 : a; // se vier em cm, normaliza para m
  }

  double? get _alturaCentimetros {
    final aM = _alturaMetros;
    if (aM == null) return null;
    return aM * 100.0;
  }

  double? get _imc {
    if (_peso == null) return null;
    final aM = _alturaMetros;
    if (aM == null || aM == 0) return null;
    return _peso! / (aM * aM);
  }

  Periodo _periodo = Periodo.semana;
  DateTime _baseDate = DateTime.now().toLocal();

  double? _peso;
  double? _altura;
  int? _pacienteId;
  String? _token;

  final LocalDatabaseService _localDb = LocalDatabaseService();

  Map<String, double> _pesoLogs = {}; // 'yyyy-MM-dd' -> kg
  Map<String, double> _cinturaLogs = {}; // cm
  Map<String, double> _quadrilLogs = {}; // cm
  Map<String, double> _bracoLogs = {}; // cm
  Map<String, double> _pernaLogs = {}; // cm

  // Exibição do gráfico de medidas
  MedidaKind _medidaSelecionada = MedidaKind.cintura;

  final PlanoAlimentarService _planoAlimentarService =
  PlanoAlimentarService();
  List<Dieta> _dietas = const [];

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasEApi();
    _carregarDietas();
  }

  Future<void> _carregarPreferenciasEApi() async {
    final prefs = await SharedPreferences.getInstance();

    _peso = (prefs.getDouble('peso') ?? (prefs.getInt('peso')?.toDouble()));
    _altura =
    (prefs.getDouble('altura') ?? (prefs.getInt('altura')?.toDouble()));

    _pacienteId = prefs.getInt('paciente_id') ?? 0;
    _token = prefs.getString('token');

    final id = _pacienteId ?? 0;

    _pesoLogs = _readLogsMap(prefs.getString('logs_peso_$id'));
    _cinturaLogs = _readLogsMap(prefs.getString('logs_cintura_$id'));
    _quadrilLogs = _readLogsMap(prefs.getString('logs_quadril_$id'));
    _bracoLogs = _readLogsMap(prefs.getString('logs_braco_$id'));
    _pernaLogs = _readLogsMap(prefs.getString('logs_perna_$id'));

    await _carregarLogsDoSQLite();

    try {
      await _carregarDadosDoWeb(_pacienteId ?? 0, _token);
    } catch (e) {
      if (kDebugMode) debugPrint('Falha ao carregar do WEB: $e');
    }

    if (mounted) setState(() {});
  }

  Future<void> _carregarDietas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int pid =
          prefs.getInt('paciente_id') ?? (_pacienteId ?? 0) ?? 0;
      if (pid == 0) return;

      final dietas =
      await _planoAlimentarService.getDietasByPacienteId(pid);

      if (mounted) setState(() => _dietas = dietas);
    } catch (e) {
      if (kDebugMode) debugPrint('Falha ao carregar dietas: $e');
    }
  }

  Future<void> _carregarLogsDoSQLite() async {
    final id = _pacienteId ?? 0;
    if (id == 0) return;

    try {
      final rows = await _localDb.getRegistrosDiariosByPaciente(id);
      for (final row in rows) {
        final dataStr = row['data'] as String?;
        if (dataStr == null) continue;
        DateTime? data;
        try {
          data = DateTime.parse(dataStr);
        } catch (_) {
          continue;
        }
        final key = _diaKey(data);

        final peso = _toDouble(row['peso']);
        final cintura = _toDouble(row['cintura']);
        final quadril = _toDouble(row['quadril']);
        final braco = _toDouble(row['braco']);
        final perna = _toDouble(row['perna']);

        if (peso != null) _pesoLogs[key] = peso;
        if (cintura != null) _cinturaLogs[key] = cintura;
        if (quadril != null) _quadrilLogs[key] = quadril;
        if (braco != null) _bracoLogs[key] = braco;
        if (perna != null) _pernaLogs[key] = perna;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Falha ao carregar registros_diarios do SQLite: $e');
      }
    }
  }

  Map<String, double> _readLogsMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> m = jsonDecode(raw);
      return m.map((k, v) {
        final dv =
        (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
        return MapEntry(k, dv);
      });
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8'
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _composeUri(String path) => Uri.parse('$kApiBaseUrl$path');

  String _applyId(String pattern, int id) =>
      pattern.replaceAll('{id}', id.toString());

  Future<Map<String, dynamic>?> _getPatientByIdSmart(int pacienteId) async {
    if (pacienteId == 0) return null;
    for (final pattern in kGetByIdPathVariants) {
      final path = _applyId(pattern, pacienteId);
      final uri = _composeUri(path);
      try {
        final resp = await http.get(uri, headers: _buildHeaders());
        if (kDebugMode) {
          debugPrint('GET ${uri.toString()} -> ${resp.statusCode}');
        }
        if (resp.statusCode == 200) {
          final body = resp.body.isEmpty ? null : jsonDecode(resp.body);
          if (body == null) return null;
          if (body is List && body.isNotEmpty) {
            return Map<String, dynamic>.from(body.first);
          } else if (body is Map) {
            return Map<String, dynamic>.from(body);
          }
        } else if (resp.statusCode == 404) {
          continue;
        } else {
          break;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Erro GET $uri: $e');
      }
    }
    return null;
  }

  Future<void> _carregarDadosDoWeb(int pacienteId, String? token) async {
    final p = await _getPatientByIdSmart(pacienteId);
    if (p == null) return;

    final double? pesoApi = _toDouble(p['peso']);
    final double? alturaApi = _toDouble(p['altura']);

    if (pesoApi != null) _peso = pesoApi;
    if (alturaApi != null) _altura = alturaApi;
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
    final wd = d.weekday;
    return _dateOnly(d.subtract(Duration(days: wd - 1)));
  }

  DateTime _fimDaSemana(DateTime d) =>
      _inicioDaSemana(d).add(const Duration(days: 6));

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

  // -------------------- Construção de SPOTS para gráficos --------------------
  final Map<String, Map<String, bool>> _checksCache = {};
  String _diaKey(DateTime d) => _keyFormatter.format(_dateOnly(d));

  String _checksKey(DateTime d) {
    final baseDia = _diaKey(d);
    final id = _pacienteId ?? 0;
    if (id == 0) return 'checks_$baseDia';
    return 'checks_${id}_$baseDia';
  }

  List<FlSpot> _spotsFromLog(Map<String, double> log, List<DateTime> datas) {
    final List<FlSpot> spots = [];
    for (int i = 0; i < datas.length; i++) {
      final key = _diaKey(datas[i]);
      final v = log[key];
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
      }
    }
    return spots;
  }

  ({double minY, double maxY}) _rangeYFromSpots(List<FlSpot> spots,
      {double pad = 1}) {
    if (spots.isEmpty) return (minY: 0, maxY: 1);
    double minY = spots.first.y, maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    return (minY: (minY - pad), maxY: (maxY + pad));
  }


  Future<Map<String, bool>> _loadChecksParaDia(DateTime dia) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checksKey(dia));
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = json.decode(raw);
      return decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, bool>> _getChecksMap(DateTime dia) async {
    final dk = _checksKey(dia);
    if (_checksCache.containsKey(dk)) return _checksCache[dk]!;
    final loaded = await _loadChecksParaDia(dia);
    _checksCache[dk] = loaded;
    return loaded;
  }

  String _normalizeTipo(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('lanche') &&
        (v.contains('manhã') || v.contains('manha'))) {
      return 'Lanche da manhã';
    }
    if (v.contains('lanche') && v.contains('tarde')) {
      return 'Lanche da tarde';
    }
    if (v.contains('café')) return 'Café da Manhã';
    if (v.contains('almo')) return 'Almoço';
    if (v.contains('jantar')) return 'Jantar';
    if (v.contains('lanche')) return 'Lanche';
    if (v.contains('ceia')) return 'Ceia';
    return raw.trim().isEmpty ? 'Outros' : raw.trim();
  }

  String _alimentoKey(String tipo, int? refeicaoId, dynamic alimento) {
    int? aid;
    try {
      aid = (alimento.id as int?);
    } catch (_) {}
    if (aid == null) {
      try {
        aid = (alimento.alimentoId as int?);
      } catch (_) {}
    }
    if (aid == null) {
      try {
        aid = (alimento.alimento_id as int?);
      } catch (_) {}
    }

    String nome = '';
    try {
      nome = (alimento.nome ?? '').toString();
    } catch (_) {}

    final t = _normalizeTipo(tipo);
    final rid = refeicaoId?.toString() ?? '0';
    final a = aid?.toString() ?? '';
    return 't:$t|r:$rid|a:$a|n:$nome';
  }

  String _tipoFromRefeicao(Refeicao r) {
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

  int? _idFromRefeicao(Refeicao r) {
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

  Future<void> _salvarKcalNoSQLite(DateTime dia, double kcal) async {
    final id = _pacienteId ?? 0;
    if (id == 0) return;
    try {
      await _localDb.upsertRegistroDiario(
        pacienteId: id,
        data: dia,
        kcalDia: kcal,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Falha ao salvar kcal no SQLite: $e');
      }
    }
  }

  Future<double> _kcalNoDia(DateTime dia) async {
    // Tenta calcular com base nas dietas + checks
    if (_dietas.isNotEmpty) {
      final checks = await _getChecksMap(dia);
      if (checks.isNotEmpty) {
        // filtra dietas válidas para o dia
        final dOnly = _dateOnly(dia);
        final dietasValidas = _dietas.where((d) {
          final inicio = d.dataInicio;
          final fim = d.dataTermino;
          if (inicio == null || fim == null) return false;
          final i = _dateOnly(inicio);
          final f = _dateOnly(fim);
          return !dOnly.isBefore(i) && !dOnly.isAfter(f);
        });

        num total = 0;
        for (final d in dietasValidas) {
          for (final r in d.refeicoes) {
            final String tipo = _tipoFromRefeicao(r);
            final int? rid = _idFromRefeicao(r);
            final List alimentos = (r.alimentos as List?) ?? const [];
            for (final a in alimentos) {
              num? kcal;
              try {
                kcal = (a.calorias ?? a.kcal) as num?;
              } catch (_) {}
              if (kcal == null) continue;
              final key = _alimentoKey(tipo, rid, a);
              if (checks[key] == true) total += kcal;
            }
          }
        }

        final totalDouble = total.toDouble();
        await _salvarKcalNoSQLite(dia, totalDouble);
        return totalDouble;
      }
    }

    // Se não foi possível calcular, tenta reaproveitar o valor salvo no SQLite
    final id = _pacienteId ?? 0;
    if (id != 0) {
      try {
        final row = await _localDb.getRegistroDiario(id, dia);
        if (row != null) {
          final cached = _toDouble(row['kcal_dia']);
          if (cached != null) return cached;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Falha ao ler kcal do SQLite: $e');
        }
      }
    }

    return 0;
  }

  Future<List<double>> _serieKcal(List<DateTime> datas) async {
    final List<double> serie = [];
    for (final d in datas) {
      final v = await _kcalNoDia(d);
      serie.add(v);
    }
    return serie;
  }

  ({double minY, double maxY}) _rangeFromValues(List<double> values,
      {double pad = 20}) {
    if (values.isEmpty) return (minY: 0, maxY: 100);
    double minY = values.first, maxY = values.first;
    for (final v in values) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    if (minY == maxY) {
      minY = 0;
      maxY = maxY + 100;
    }
    return (minY: (minY - pad).clamp(0, double.infinity), maxY: (maxY + pad));
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final datas = _datasNoPeriodo(_baseDate, _periodo);
    final pesoSpots = _spotsFromLog(_pesoLogs, datas);
    final ({double minY, double maxY}) pesoRange =
    _rangeYFromSpots(pesoSpots, pad: 0.5);

    // medidas
    final Map<MedidaKind, Map<String, double>> allLogs = {
      MedidaKind.cintura: _cinturaLogs,
      MedidaKind.quadril: _quadrilLogs,
      MedidaKind.braco: _bracoLogs,
      MedidaKind.perna: _pernaLogs,
    };
    final medidaSpots = _spotsFromLog(allLogs[_medidaSelecionada]!, datas);
    final ({double minY, double maxY}) medidaRange =
    _rangeYFromSpots(medidaSpots, pad: 0.5);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [kPrimary, kPrimarySoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        title: Column(
          children: const [
            Text('Relatórios',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: .2)),
            SizedBox(height: 2),
            Text('Acompanhamento e métricas',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // -------------------- Filtro de período --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Período',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kText)),
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
                      Expanded(
                        child: Text(_labelPeriodo(),
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                      ),
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

            // -------------------- Kcal consumidas por dia (gráfico) --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_fire_department, color: kPrimary),
                      SizedBox(width: 8),
                      Text('Kcal consumidas por dia',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: kText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<double>>(
                    future: _serieKcal(datas),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _emptyChartPlaceholder(
                            'Calculando consumo de kcal...');
                      }
                      final values = snap.data ?? const <double>[];
                      final bool allZero =
                          values.isEmpty || values.every((v) => v == 0);
                      if (allZero) {
                        return _emptyChartPlaceholder(
                            'Sem consumo marcado no período selecionado.');
                      }
                      final range = _rangeFromValues(values);
                      return SizedBox(
                        height: 220,
                        child: _buildBarChartKcal(datas, values, range),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- Peso (gráfico) --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peso diário (kg)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kText)),
                  const SizedBox(height: 10),
                  if (pesoSpots.isEmpty)
                    _emptyChartPlaceholder(
                        'Sem registros de peso neste período.\nCadastre pesos na aba Registro.'),
                  if (pesoSpots.isNotEmpty)
                    SizedBox(
                        height: 220,
                        child: _buildLineChart(
                            datas, pesoSpots, pesoRange,
                            unidade: 'kg')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- IMC (somente leitura) --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
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
                        const Text('IMC Atual',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: kText)),
                        const SizedBox(height: 6),
                        Text(
                          _imc == null
                              ? '--'
                              : _imc!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kText),
                        ),
                        const SizedBox(height: 4),
                        Text(_imcCategoria,
                            style: TextStyle(
                                color: _imcCor,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          _alturaCentimetros == null
                              ? 'Altura: --'
                              : 'Altura: ${_alturaCentimetros!.toStringAsFixed(1)} cm',
                          style:
                          const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          _peso == null
                              ? 'Peso: --'
                              : 'Peso: ${_peso!.toStringAsFixed(1)} kg',
                          style:
                          const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- Gráfico de medidas --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Evolução das medidas (cm)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: kText)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _medidaSelector(), // Wrap com os ChoiceChips
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      if (medidaSpots.isEmpty) {
                        return _emptyChartPlaceholder(
                            'Sem registros para esta medida.\nCadastre medidas na aba Registro.');
                      }
                      return SizedBox(
                        height: 200,
                        child: _buildLineChart(
                            datas, medidaSpots, medidaRange,
                            unidade: 'cm'),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -------------------- Widgets auxiliares --------------------
  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(0, 4))
    ],
    border: Border.all(color: const Color(0x11000000)),
  );

  Widget _emptyChartPlaceholder(String msg) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildLineChart(List<DateTime> datas, List<FlSpot> spots,
      ({double minY, double maxY}) range,
      {required String unidade}) {
    return LineChart(
      LineChartData(
        minY: range.minY,
        maxY: range.maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= datas.length) {
                  return const SizedBox.shrink();
                }
                final d = datas[idx];
                return Text(
                  _periodo == Periodo.ano
                      ? DateFormat('MM', 'pt_BR').format(d)
                      : DateFormat('dd', 'pt_BR').format(d),
                  style: const TextStyle(fontSize: 10),
                );
              },
              interval: 1,
              reservedSize: 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles:
            SideTitles(showTitles: true, reservedSize: 44),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData:
        FlGridData(show: true, drawHorizontalLine: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            dotData: const FlDotData(show: true),
            color: kPrimary,
            barWidth: 3,
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((it) {
              final idx = it.x.toInt();
              final d = datas[idx];
              final labelData =
              DateFormat('dd/MM', 'pt_BR').format(d);
              return LineTooltipItem(
                  '$labelData ${it.y.toStringAsFixed(1)} $unidade',
                  const TextStyle(color: Colors.white));
            })
                .toList(),
          ),
        ),
      ),
    );
  }

  double _yIntervalForKcal(double span) {
    if (span <= 120) return 20; // valores próximos (20 kcal)
    if (span <= 300) return 50; // faixa pequena
    if (span <= 600) return 100; // faixa média
    return 200; // faixa maior
  }

  Widget _buildBarChartKcal(List<DateTime> datas, List<double> valores,
      ({double minY, double maxY}) range) {
    final span = (range.maxY - range.minY).abs();
    final yInterval = _yIntervalForKcal(span);
    final nf = NumberFormat('#,##0', 'pt_BR'); // ex.: 2.865 (sem 'K')

    return BarChart(
      BarChartData(
        minY: range.minY,
        maxY: range.maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  nf.format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= datas.length) {
                  return const SizedBox.shrink();
                }
                final d = datas[idx];
                return Text(
                  _periodo == Periodo.ano
                      ? DateFormat('MM', 'pt_BR').format(d)
                      : DateFormat('dd', 'pt_BR').format(d),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = datas[group.x.toInt()];
              final label =
              DateFormat('dd/MM', 'pt_BR').format(d);
              final v = rod.toY;
              return BarTooltipItem(
                '$label ${v.toStringAsFixed(0)} kcal',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        barGroups: List.generate(valores.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: valores[i],
                width: 12,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
                color: kPrimary,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _medidaSelector() {
    String label(MedidaKind k) {
      switch (k) {
        case MedidaKind.cintura:
          return 'Cintura';
        case MedidaKind.quadril:
          return 'Quadril';
        case MedidaKind.braco:
          return 'Braço';
        case MedidaKind.perna:
          return 'Perna';
      }
    }

    return Wrap(
      spacing: 6,
      children: MedidaKind.values.map((k) {
        final selected = _medidaSelecionada == k;
        return ChoiceChip(
          label: Text(label(k)),
          selected: selected,
          onSelected: (_) =>
              setState(() => _medidaSelecionada = k),
          selectedColor: kPrimarySoft,
          labelStyle: TextStyle(
              color: selected ? Colors.white : kText,
              fontWeight: FontWeight.w600),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0x11000000)),
        );
      }).toList(),
    );
  }

  Widget _chipPeriodo(String label, Periodo p) {
    final selected = _periodo == p;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _periodo = p),
      selectedColor: kPrimarySoft,
      labelStyle: TextStyle(
          color: selected ? Colors.white : kText,
          fontWeight: FontWeight.w600),
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

  // --- IMC helpers ---
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
}