import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/registro_local_database_service.dart';
import 'package:tcc_aplicativo_de_acompanhamento_nutricional/data/services/local_database_service.dart';

// === Cores do tema ===
const Color kBg = Color(0xFFF5F5F5);
const Color kPrimary = Color(0xFFEC8800);
const Color kPrimarySoft = Color(0xFFFFB36B);
const Color kText = Color(0xFF444444);

// === API do projeto WEB ===
const String kApiBaseUrl =
String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8800');

const List<String> kUpdatePathVariants = [
  '/patient/updatePatientById/{id}',
  '/patient/update/{id}',
  '/patient/{id}',
  '/patients/{id}',
  '/api/patient/updatePatientById/{id}',
  '/api/patient/{id}',
  '/patient/updatePatientById',
  '/api/patient/updatePatientById',
];

final DateFormat _fmtDia = DateFormat('dd/MM/yyyy', 'pt_BR');
final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd', 'pt_BR');

// Medidas registráveis
enum MedidaKind { cintura, quadril, braco, perna }

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  // Data do registro
  DateTime _dataRegistro = DateTime.now();

  // Dados atuais
  double? _peso;
  double? _altura; // armazenada em metros
  double? _cintura;
  double? _quadril;
  double? _braco;
  double? _perna;
  int? _pacienteId;
  String? _token;

  // Controllers dos campos
  final TextEditingController _pesoCtrl = TextEditingController();
  final TextEditingController _alturaCmCtrl = TextEditingController();
  final TextEditingController _cinturaCtrl = TextEditingController();
  final TextEditingController _quadrilCtrl = TextEditingController();
  final TextEditingController _bracoCtrl = TextEditingController();
  final TextEditingController _pernaCtrl = TextEditingController();

  Map<String, double> _pesoLogs = {}; // 'yyyy-MM-dd' -> kg
  Map<String, double> _cinturaLogs = {}; // cm
  Map<String, double> _quadrilLogs = {}; // cm
  Map<String, double> _bracoLogs = {}; // cm
  Map<String, double> _pernaLogs = {}; // cm

  final RegistroLocalDatabaseService _registroLocalDb =
  RegistroLocalDatabaseService();

  final LocalDatabaseService _localDb = LocalDatabaseService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _carregarPreferencias();
    await _syncPendingUpdates(); // tenta sincronizar o que foi salvo offline
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _alturaCmCtrl.dispose();
    _cinturaCtrl.dispose();
    _quadrilCtrl.dispose();
    _bracoCtrl.dispose();
    _pernaCtrl.dispose();
    super.dispose();
  }

  Future<bool> _isOffline() async {
    final result = await Connectivity().checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return result.contains(ConnectivityResult.none);
    } else {
      return result == ConnectivityResult.none;
    }
  }

  Future<void> _carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    _peso = (prefs.getDouble('peso') ?? (prefs.getInt('peso')?.toDouble()));
    _altura =
    (prefs.getDouble('altura') ?? (prefs.getInt('altura')?.toDouble()));
    _cintura = (prefs.getDouble('med_cintura') ??
        (prefs.getInt('med_cintura')?.toDouble()));
    _quadril = (prefs.getDouble('med_quadril') ??
        (prefs.getInt('med_quadril')?.toDouble()));
    _braco =
    (prefs.getDouble('med_braco') ?? (prefs.getInt('med_braco')?.toDouble()));
    _perna =
    (prefs.getDouble('med_perna') ?? (prefs.getInt('med_perna')?.toDouble()));

    _pacienteId = prefs.getInt('paciente_id') ?? 0;
    _token = prefs.getString('token');

    _pesoLogs = _readLogsMap(prefs.getString(_logsKey('peso')));
    _cinturaLogs = _readLogsMap(prefs.getString(_logsKey('cintura')));
    _quadrilLogs = _readLogsMap(prefs.getString(_logsKey('quadril')));
    _bracoLogs = _readLogsMap(prefs.getString(_logsKey('braco')));
    _pernaLogs = _readLogsMap(prefs.getString(_logsKey('perna')));

    _syncControllersFromState();
    if (mounted) setState(() {});
  }

  String _logsKey(String tipo) {
    final id = _pacienteId ?? 0;
    return 'logs_${tipo}_$id';
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

  Future<void> _writeLogsMap(String key, Map<String, double> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(map));
  }

  void _syncControllersFromState() {
    _pesoCtrl.text = _peso == null ? '' : _peso!.toStringAsFixed(1);
    final alturaCm = _altura == null ? null : _altura! * 100.0;
    _alturaCmCtrl.text =
    alturaCm == null ? '' : alturaCm.toStringAsFixed(1); // mostra em cm
    _cinturaCtrl.text =
    _cintura == null ? '' : _cintura!.toStringAsFixed(1);
    _quadrilCtrl.text =
    _quadril == null ? '' : _quadril!.toStringAsFixed(1);
    _bracoCtrl.text = _braco == null ? '' : _braco!.toStringAsFixed(1);
    _pernaCtrl.text = _perna == null ? '' : _perna!.toStringAsFixed(1);
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

  // Aplica o payload localmente (SharedPreferences + variáveis de estado)
  Future<void> _aplicarPayloadLocal(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();

    if (payload.containsKey('peso')) {
      final v = (payload['peso'] as num).toDouble();
      await prefs.setDouble('peso', v);
      _peso = v;
    }
    if (payload.containsKey('altura')) {
      final v = (payload['altura'] as num).toDouble();
      await prefs.setDouble('altura', v);
      _altura = v;
    }
    if (payload.containsKey('circunferencia_cintura')) {
      final v = (payload['circunferencia_cintura'] as num).toDouble();
      await prefs.setDouble('med_cintura', v);
      _cintura = v;
    }
    if (payload.containsKey('circunferencia_quadril')) {
      final v = (payload['circunferencia_quadril'] as num).toDouble();
      await prefs.setDouble('med_quadril', v);
      _quadril = v;
    }
    if (payload.containsKey('circunferencia_bracos')) {
      final v = (payload['circunferencia_bracos'] as num).toDouble();
      await prefs.setDouble('med_braco', v);
      _braco = v;
    }
    if (payload.containsKey('circunferencia_pernas')) {
      final v = (payload['circunferencia_pernas'] as num).toDouble();
      await prefs.setDouble('med_perna', v);
      _perna = v;
    }
  }

  // -------------------- Persistência no backend + offline --------------------
  Future<bool> _atualizarPaciente(Map<String, dynamic> payload,
      {bool fromSync = false}) async {
    if ((_pacienteId ?? 0) == 0) {
      if (!fromSync) {
        _showSnack('Paciente não identificado (paciente_id=0).',
            error: true);
      }
      return false;
    }
    final int id = _pacienteId!;

    // 1) Se for ação do usuário (não é sync automático)
    if (!fromSync) {
      final offline = await _isOffline();
      if (offline) {
        await _registroLocalDb.addPendingUpdate(id, payload);
        await _aplicarPayloadLocal(payload);
        if (mounted) {
          _showSnack(
            'Sem internet. Alterações salvas localmente e serão sincronizadas depois.',
          );
        }
        return true;
      }
    }

    // 2) Tenta mandar para o backend (PATCH/PUT em vários endpoints)
    final methods = <String>['PATCH', 'PUT'];

    for (final pathPattern in kUpdatePathVariants) {
      final bool expectsIdInBody = !pathPattern.contains('{id}');
      final String path =
      expectsIdInBody ? pathPattern : _applyId(pathPattern, id);
      final Uri uri = _composeUri(path);

      for (final method in methods) {
        try {
          final bodyMap =
          expectsIdInBody ? {...payload, 'id': id} : payload;
          final body = jsonEncode(bodyMap);

          http.Response resp;
          if (method == 'PATCH') {
            resp =
            await http.patch(uri, headers: _buildHeaders(), body: body);
          } else {
            resp =
            await http.put(uri, headers: _buildHeaders(), body: body);
          }

          if (kDebugMode) {
            debugPrint(
                '$method ${uri.toString()} -> ${resp.statusCode} ${resp.body}');
          }

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            // Deu certo no servidor → aplica localmente e sai
            await _aplicarPayloadLocal(payload);
            if (!fromSync && mounted) {
              _showSnack('Salvo com sucesso!');
            }
            return true;
          }

          if (resp.statusCode == 404 || resp.statusCode == 405) {
            continue;
          } else {
            // Erro de servidor conhecido (ex.: 400, 500...)
            if (!fromSync && mounted) {
              _showSnack('Falha ao salvar (${resp.statusCode}).',
                  error: true);
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Erro $method $uri: $e');
          }

          if (!fromSync) {
            await _registroLocalDb.addPendingUpdate(id, payload);
            await _aplicarPayloadLocal(payload);
            if (mounted) {
              _showSnack(
                'Sem conexão com o servidor. Alterações salvas localmente e serão sincronizadas depois.',
              );
            }
            return true;
          } else {
            return false;
          }
        }
      }
    }

    if (!fromSync && mounted) {
      _showSnack('Falha ao salvar (rota não encontrada).', error: true);
    }
    return false;
  }

  // Sincroniza os registros pendentes do SQLite assim que encontrar internet
  Future<void> _syncPendingUpdates() async {
    final id = _pacienteId ?? 0;
    if (id == 0) return;

    final offline = await _isOffline();
    if (offline) return;

    final pendentes = await _registroLocalDb.getPendingUpdates(id);
    if (pendentes.isEmpty) return;

    for (final row in pendentes) {
      final rowId = row['id'] as int;
      final raw = row['payload'] as String?;
      if (raw == null) {
        await _registroLocalDb.deleteUpdate(rowId);
        continue;
      }

      Map<String, dynamic>? payload;
      try {
        payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        await _registroLocalDb.deleteUpdate(rowId);
        continue;
      }

      final ok = await _atualizarPaciente(payload, fromSync: true);
      if (ok) {
        await _registroLocalDb.deleteUpdate(rowId);
      } else {
        break;
      }
    }

    if (mounted) {
      _showSnack('Registros offline sincronizados!');
    }
  }

  String _keyFor(DateTime d) =>
      _keyFormatter.format(DateTime(d.year, d.month, d.day));

  Future<void> _salvarRegistroDiarioNoSQLite(DateTime d) async {
    final id = _pacienteId ?? 0;
    if (id == 0) return;

    final k = _keyFor(d);
    final peso = _pesoLogs[k];
    final cintura = _cinturaLogs[k];
    final quadril = _quadrilLogs[k];
    final braco = _bracoLogs[k];
    final perna = _pernaLogs[k];

    try {
      await _localDb.upsertRegistroDiario(
        pacienteId: id,
        data: d,
        peso: peso,
        cintura: cintura,
        quadril: quadril,
        braco: braco,
        perna: perna,
        // kcalDia será preenchido na tela de Relatórios
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao salvar registro diário no SQLite: \$e');
      }
    }
  }

  Future<void> _registrarPesoNoDia(DateTime d, double valor) async {
    final k = _keyFor(d);
    setState(() => _pesoLogs[k] = valor);
    await _writeLogsMap(_logsKey('peso'), _pesoLogs);
    await _salvarRegistroDiarioNoSQLite(d);
  }

  Future<void> _registrarMedidaNoDia(
      MedidaKind kind, DateTime d, double valor) async {
    final k = _keyFor(d);
    setState(() {
      switch (kind) {
        case MedidaKind.cintura:
          _cinturaLogs[k] = valor;
          break;
        case MedidaKind.quadril:
          _quadrilLogs[k] = valor;
          break;
        case MedidaKind.braco:
          _bracoLogs[k] = valor;
          break;
        case MedidaKind.perna:
          _pernaLogs[k] = valor;
          break;
      }
    });
    switch (kind) {
      case MedidaKind.cintura:
        await _writeLogsMap(_logsKey('cintura'), _cinturaLogs);
        break;
      case MedidaKind.quadril:
        await _writeLogsMap(_logsKey('quadril'), _quadrilLogs);
        break;
      case MedidaKind.braco:
        await _writeLogsMap(_logsKey('braco'), _bracoLogs);
        break;
      case MedidaKind.perna:
        await _writeLogsMap(_logsKey('perna'), _pernaLogs);
        break;
    }

    await _salvarRegistroDiarioNoSQLite(d);
  }

  // -------------------- Ações dos botões Salvar --------------------
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.'));
    }
    return null;
  }

  Future<void> _salvarPeso() async {
    final parsed = _toDouble(_pesoCtrl.text);
    if (parsed == null) {
      _showSnack('Peso inválido.', error: true);
      return;
    }
    await _registrarPesoNoDia(_dataRegistro, parsed);
    final ok = await _atualizarPaciente({'peso': parsed});
    if (ok) setState(() {});
  }

  Future<void> _salvarAlturaCm() async {
    final parsedCm = _toDouble(_alturaCmCtrl.text);
    if (parsedCm == null) {
      _showSnack('Altura inválida.', error: true);
      return;
    }
    final alturaM = parsedCm / 100.0;
    final ok = await _atualizarPaciente({'altura': alturaM});
    if (ok) setState(() {});
  }

  Future<void> _salvarCintura() async {
    final parsed = _toDouble(_cinturaCtrl.text);
    if (parsed == null) {
      _showSnack('Cintura inválida.', error: true);
      return;
    }
    await _registrarMedidaNoDia(MedidaKind.cintura, _dataRegistro, parsed);
    final ok =
    await _atualizarPaciente({'circunferencia_cintura': parsed});
    if (ok) setState(() {});
  }

  Future<void> _salvarQuadril() async {
    final parsed = _toDouble(_quadrilCtrl.text);
    if (parsed == null) {
      _showSnack('Quadril inválido.', error: true);
      return;
    }
    await _registrarMedidaNoDia(MedidaKind.quadril, _dataRegistro, parsed);
    final ok =
    await _atualizarPaciente({'circunferencia_quadril': parsed});
    if (ok) setState(() {});
  }

  Future<void> _salvarBraco() async {
    final parsed = _toDouble(_bracoCtrl.text);
    if (parsed == null) {
      _showSnack('Braço inválido.', error: true);
      return;
    }
    await _registrarMedidaNoDia(MedidaKind.braco, _dataRegistro, parsed);
    final ok =
    await _atualizarPaciente({'circunferencia_bracos': parsed});
    if (ok) setState(() {});
  }

  Future<void> _salvarPerna() async {
    final parsed = _toDouble(_pernaCtrl.text);
    if (parsed == null) {
      _showSnack('Perna inválida.', error: true);
      return;
    }
    await _registrarMedidaNoDia(MedidaKind.perna, _dataRegistro, parsed);
    final ok =
    await _atualizarPaciente({'circunferencia_pernas': parsed});
    if (ok) setState(() {});
  }

  Future<void> _registrarTudo() async {
    // Parse dos campos
    final pesoParsed = _toDouble(_pesoCtrl.text);
    final alturaCmParsed = _toDouble(_alturaCmCtrl.text);
    final cinturaParsed = _toDouble(_cinturaCtrl.text);
    final quadrilParsed = _toDouble(_quadrilCtrl.text);
    final bracoParsed = _toDouble(_bracoCtrl.text);
    final pernaParsed = _toDouble(_pernaCtrl.text);

    // Monta payload apenas com valores válidos
    final Map<String, dynamic> payload = {};
    if (pesoParsed != null) payload['peso'] = pesoParsed;
    if (alturaCmParsed != null) {
      payload['altura'] = alturaCmParsed / 100.0; // cm -> m
    }
    if (cinturaParsed != null) {
      payload['circunferencia_cintura'] = cinturaParsed;
    }
    if (quadrilParsed != null) {
      payload['circunferencia_quadril'] = quadrilParsed;
    }
    if (bracoParsed != null) {
      payload['circunferencia_bracos'] = bracoParsed;
    }
    if (pernaParsed != null) {
      payload['circunferencia_pernas'] = pernaParsed;
    }

    if (payload.isEmpty) {
      _showSnack('Preencha ao menos um campo para registrar.',
          error: true);
      return;
    }

    // Registra logs locais por data selecionada
    if (pesoParsed != null) {
      await _registrarPesoNoDia(_dataRegistro, pesoParsed);
    }
    if (cinturaParsed != null) {
      await _registrarMedidaNoDia(
          MedidaKind.cintura, _dataRegistro, cinturaParsed);
    }
    if (quadrilParsed != null) {
      await _registrarMedidaNoDia(
          MedidaKind.quadril, _dataRegistro, quadrilParsed);
    }
    if (bracoParsed != null) {
      await _registrarMedidaNoDia(
          MedidaKind.braco, _dataRegistro, bracoParsed);
    }
    if (pernaParsed != null) {
      await _registrarMedidaNoDia(
          MedidaKind.perna, _dataRegistro, pernaParsed);
    }

    // Chama backend em uma única atualização (ou enfileira offline)
    final ok = await _atualizarPaciente(payload);
    if (ok) {
      setState(() {});
      _showSnack('Medidas registradas com sucesso!');
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
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
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Registro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // -------------------- Escolha da data do registro --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Row(
                children: [
                  const Icon(Icons.edit_calendar_outlined,
                      color: kPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data do registro: ${_fmtDia.format(_dataRegistro)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: kText),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _dataRegistro,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        helpText: 'Selecione a data do registro',
                        confirmText: 'OK',
                        cancelText: 'Cancelar',
                      );
                      if (picked != null) {
                        setState(() => _dataRegistro = picked);
                      }
                    },
                    child: const Text('Alterar'),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- Altura --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Altura',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kText)),
                  const SizedBox(height: 10),
                  _editableStatTile(
                    icon: Icons.height,
                    title: 'Altura (cm)',
                    controller: _alturaCmCtrl,
                    suffix: 'cm',
                    onSave: _salvarAlturaCm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- Peso --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peso',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kText)),
                  const SizedBox(height: 10),
                  _editableStatTile(
                    icon: Icons.monitor_weight_outlined,
                    title:
                    'Peso (kg) — será registrado na data escolhida',
                    controller: _pesoCtrl,
                    suffix: 'kg',
                    onSave: _salvarPeso,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------------------- Medidas corporais --------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Medidas corporais (cm)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kText)),
                  const SizedBox(height: 10),
                  _editableMedidaCard(
                    icon: Icons.straighten,
                    titulo: 'Cintura (cm)',
                    controller: _cinturaCtrl,
                    onSave: _salvarCintura,
                  ),
                  const SizedBox(height: 10),
                  _editableMedidaCard(
                    icon: Icons.accessibility_new,
                    titulo: 'Quadril (cm)',
                    controller: _quadrilCtrl,
                    onSave: _salvarQuadril,
                  ),
                  const SizedBox(height: 10),
                  _editableMedidaCard(
                    icon: Icons.fitness_center,
                    titulo: 'Braço (cm)',
                    controller: _bracoCtrl,
                    onSave: _salvarBraco,
                  ),
                  const SizedBox(height: 10),
                  _editableMedidaCard(
                    icon: Icons.directions_walk,
                    titulo: 'Perna (cm)',
                    controller: _pernaCtrl,
                    onSave: _salvarPerna,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Registrar medidas'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _registrarTudo,
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

  Widget _editableStatTile({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String suffix,
    required Future<void> Function() onSave,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: kText)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: controller,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixText: suffix,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => onSave(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: kPrimary),
            onPressed: () => onSave(),
          ),
        ],
      ),
    );
  }

  Widget _editableMedidaCard({
    required IconData icon,
    required String titulo,
    required TextEditingController controller,
    required Future<void> Function() onSave,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: kPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: kText)),
              ),
              IconButton(
                icon: const Icon(Icons.save_outlined, color: kPrimary),
                onPressed: () => onSave(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                suffixText: 'cm',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : kPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}