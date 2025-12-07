import 'package:flutter/material.dart';
import '../../data/services/paciente_api.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey = GlobalKey<FormState>();

  // Paleta
  static const Color kBg = Color(0xFFF5F5F5);
  static const Color kPrimary = Color(0xFFEC8800);
  static const Color kText = Color(0xFF444444);
  static const Color kCard = Colors.white;

  // Controllers
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  String? _genero; // espera 'M' ou 'F' do backend

  String? _objetivo;
  int _freqExercicio = 0;
  final _restricaoAlimentarController = TextEditingController();
  final _alergiasController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _habitosAlimentaresController = TextEditingController();
  final _historicoFamiliarController = TextEditingController();
  final _doencasCronicasController = TextEditingController();
  final _medicamentosController = TextEditingController();
  final _examesSangueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final api = PacienteApi();
      final json = await api.getById();

      setState(() {
        _nomeController.text = (json['nome'] ?? '').toString();
        _emailController.text = (json['email'] ?? '').toString();
        _telefoneController.text = (json['telefone'] ?? '').toString();

        final dn = (json['dataNascimento'] ?? '').toString();
        final parsed = _parseAnyDate(dn);
        if (parsed != null) {
          _dataNascimentoController.text = _formatDate(parsed);
        }

        _genero = (json['genero'] ?? '').toString();
        _objetivo = (json['objetivo'] ?? '') as String?;

        final freqStr = (json['frequencia_exercicio_semanal'] ?? '').toString();
        final freqNum = int.tryParse(
          freqStr.split(RegExp(r'\D+')).firstWhere(
                (s) => s.isNotEmpty,
            orElse: () => '0',
          ),
        );
        _freqExercicio = (freqNum ?? 0).clamp(0, 7);

        _restricaoAlimentarController.text = (json['restricao_alimentar'] ?? '').toString();
        _alergiasController.text = (json['alergia'] ?? '').toString();
        _observacaoController.text = (json['observacao'] ?? '').toString();
        _habitosAlimentaresController.text = (json['habitos_alimentares'] ?? '').toString();
        _historicoFamiliarController.text = (json['historico_familiar_doencas'] ?? '').toString();
        _doencasCronicasController.text = (json['doencas_cronicas'] ?? '').toString();
        _medicamentosController.text = (json['medicamentos_em_uso'] ?? '').toString();
        _examesSangueController.text = (json['exames_de_sangue_relevantes'] ?? '').toString();
      });
    } catch (e) {
      debugPrint('Falha ao carregar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar seu perfil.')),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nomeController,
      _emailController,
      _telefoneController,
      _dataNascimentoController,
      _restricaoAlimentarController,
      _alergiasController,
      _observacaoController,
      _habitosAlimentaresController,
      _historicoFamiliarController,
      _doencasCronicasController,
      _medicamentosController,
      _examesSangueController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: kPrimary,
          secondary: kPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: kText),
          filled: true,
          fillColor: kCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            // === Cabeçalho atualizado para combinar com a tela de "Registro" ===
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC8800), Color(0xFFFFB36B)], // kPrimary, kPrimarySoft
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            'Perfil',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Salvar',
              onPressed: _salvarAlteracoes,
              icon: const Icon(Icons.save_rounded, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      _headerCard(), // <-- Agora com a foto do perfil
                      const SizedBox(height: 16),

                      // 1) Informações Pessoais
                      _SectionCard(
                        title: 'Informações Pessoais',
                        initiallyExpanded: false,
                        children: [
                          _text('Nome', _nomeController, validator: _required, prefixIcon: Icons.person_outline),
                          _text('Email', _emailController, keyboardType: TextInputType.emailAddress, validator: _emailValidator, prefixIcon: Icons.email_outlined),
                          _text('Telefone', _telefoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined),
                          _date('Data de nascimento', _dataNascimentoController),
                          _readonlyField('Gênero', _generoLabel()),
                        ],
                      ),

                      // 2) Informações Específicas
                      _SectionCard(
                        title: 'Informações Específicas',
                        children: [
                          _multiline('Objetivo', _observacaoController),
                          Row(
                            children: [
                              const SizedBox(width: 12),
                            ],
                          ),
                          _sliderDias(
                            label: 'Frequência de exercício semanal',
                            value: _freqExercicio,
                            onChanged: (v) => setState(() => _freqExercicio = v),
                          ),
                          _text('Restrição alimentar', _restricaoAlimentarController, prefixIcon: Icons.no_food_outlined),
                          _text('Alergias', _alergiasController, prefixIcon: Icons.health_and_safety_outlined),
                          _multiline('Hábitos alimentares', _habitosAlimentaresController),
                          _multiline('Histórico familiar de doenças', _historicoFamiliarController),
                          _multiline('Doenças crônicas', _doencasCronicasController),
                          _multiline('Medicamentos em uso', _medicamentosController),
                          _multiline('Exames de sangue relevantes', _examesSangueController),
                        ],
                      ),

                      // 3) Configurações (popup Alterar Senha + Sair)
                      _SectionCard(
                        title: 'Configurações',
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _alterarSenha,
                              icon: const Icon(Icons.lock_reset_rounded),
                              label: const Text('Alterar Senha'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _logout,
                              icon: const Icon(Icons.exit_to_app_rounded),
                              label: const Text('Sair'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Widgets auxiliares ---
  Widget _headerCard() {
    // Cabeçalho com foto do perfil (assets/images/Paciente.jpg) + dados resumidos
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1E0), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE0BF)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar com anel decorativo
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kPrimary, Color(0xFFFFC37A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundImage: const AssetImage('assets/images/Paciente.jpg'),
                backgroundColor: kPrimary.withOpacity(0.08),
              ),
            ),
            const SizedBox(width: 16),
            // Informações de título + subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dados do Paciente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText),
                  ),
                  const SizedBox(height: 6),
                  // Nome e e-mail do controller (somente visual, não editável aqui)
                  Text(
                    _nomeController.text.isNotEmpty ? _nomeController.text : '—',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _emailController.text.isNotEmpty ? _emailController.text : '—',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6D6D6D)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mantenha seu cadastro atualizado para um melhor acompanhamento clínico.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6D6D6D)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, IconData? prefixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: kText),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF9E9E9E)) : null,
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        readOnly: true,
        initialValue: value,
        style: const TextStyle(color: kText),
        decoration: InputDecoration(
          labelText: label,
        ),
      ),
    );
  }

  Widget _multiline(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: 3,
        style: const TextStyle(color: kText),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _date(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: kText),
        decoration: const InputDecoration(
          labelText: 'Data de nascimento',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final now = DateTime.now();
          final initialDate = _parseDate(controller.text) ?? DateTime(now.year - 18, now.month, now.day);
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(1900),
            lastDate: now,
            initialDate: initialDate,
          );
          if (picked != null) controller.text = _formatDate(picked);
        },
      ),
    );
  }

  Widget _sliderDias({required String label, required int value, required ValueChanged<int> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value}x/semana', style: const TextStyle(fontWeight: FontWeight.w600, color: kText)),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 7,
          divisions: 7,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
          activeColor: kPrimary,
          inactiveColor: kPrimary.withOpacity(0.25),
        ),
      ],
    );
  }

  // --- Validações ---
  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;
  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
    final ok = RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+').hasMatch(v.trim());
    return ok ? null : 'Email inválido';
  }

  // --- Salvamento ---
  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    String? dataISO;
    final dt = _parseDate(_dataNascimentoController.text);
    if (dt != null) {
      dataISO = "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    String? generoSql;
    switch ((_genero ?? '').toString().toLowerCase()) {
      case 'masculino':
      case 'm':
        generoSql = 'M';
        break;
      case 'feminino':
      case 'f':
        generoSql = 'F';
        break;
      default:
        generoSql = null;
    }

    final freqStr = '${_freqExercicio}x por semana';

    final payload = {
      'nome': _nomeController.text.trim(),
      'email': _emailController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      'dataNascimento': dataISO,
      'genero': generoSql,
      'objetivo': _objetivo,
      'restricao_alimentar': _restricaoAlimentarController.text.trim(),
      'alergia': _alergiasController.text.trim(),
      'observacao': _observacaoController.text.trim(),
      'habitos_alimentares': _habitosAlimentaresController.text.trim(),
      'historico_familiar_doencas': _historicoFamiliarController.text.trim(),
      'doencas_cronicas': _doencasCronicasController.text.trim(),
      'medicamentos_em_uso': _medicamentosController.text.trim(),
      'exames_de_sangue_relevantes': _examesSangueController.text.trim(),
      'frequencia_exercicio_semanal': freqStr,
    };

    try {
      await PacienteApi().updateById(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado com sucesso')));
    } catch (e) {
      debugPrint('Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar. Verifique os campos.')));
      }
    }
  }

  // --- Ações ---
  Future<void> _alterarSenha() async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showNew = false;
    bool showConfirm = false;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Regras dinâmicas com base no texto atual
            final pwd = newCtrl.text;
            final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
            final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
            final hasDigit = RegExp(r'\d').hasMatch(pwd);
            final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);
            final hasLen = pwd.length >= 8;

            Widget ruleRow(bool ok, String text) {
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18, color: ok ? Colors.green : const Color(0xFF9E9E9E)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          color: ok ? Colors.green : const Color(0xFF6D6D6D),
                          fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('Alterar Senha'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newCtrl,
                      obscureText: !showNew,
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        // Instrução resumida; a lista detalhada vem abaixo
                        helperText: 'Deve atender às regras abaixo.',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9E9E9E)),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => showNew = !showNew),
                          icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                        ),
                        filled: true,
                      ),
                      onChanged: (_) => setState(() {}), // atualiza a lista de regras em tempo real
                      validator: (v) {
                        final value = (v ?? '');
                        if (value.isEmpty) return 'Campo obrigatório';
                        if (value.length < 8) return 'Mínimo 8 caracteres';
                        if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Inclua ao menos 1 letra maiúscula';
                        if (!RegExp(r'[a-z]').hasMatch(value)) return 'Inclua ao menos 1 letra minúscula';
                        if (!RegExp(r'\d').hasMatch(value)) return 'Inclua ao menos 1 número';
                        if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Inclua ao menos 1 caractere especial';
                        return null;
                      },
                    ),

                    // Lista de regras que ficam verdes conforme o usuário digita
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ruleRow(hasLen, 'Pelo menos 8 caracteres'),
                          ruleRow(hasUpper, 'Pelo menos 1 letra maiúscula (A–Z)'),
                          ruleRow(hasLower, 'Pelo menos 1 letra minúscula (a–z)'),
                          ruleRow(hasDigit, 'Pelo menos 1 número (0–9)'),
                          ruleRow(hasSpecial, 'Pelo menos 1 caractere especial (!@#\$% ...)'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: !showConfirm,
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9E9E9E)),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => showConfirm = !showConfirm),
                          icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                        ),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                        if (v != newCtrl.text) return 'As senhas não coincidem';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setState(() => submitting = true);
                    try {
                      await PacienteApi().changePassword(
                        newPassword: newCtrl.text.trim(),
                        confirmPassword: confirmCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Senha alterada com sucesso.')),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Não foi possível alterar a senha: $e')),
                        );
                      }
                    } finally {
                      setState(() => submitting = false);
                    }
                  },
                  icon: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(submitting ? 'Alterando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
          (route) => false,
    );
  }

  // --- Util ---
  String _generoLabel() {
    final g = (_genero ?? '').toUpperCase().trim();
    if (g == 'M' || g == 'MASCULINO') return 'Masculino';
    if (g == 'F' || g == 'FEMININO') return 'Feminino';
    return g.isEmpty ? '—' : g; // fallback para outros valores
  }

  // --- Datas ---
  DateTime? _parseAnyDate(String? input) {
    if (input == null || input.isEmpty) return null;
    try {
      final sanitized = input.contains('T') ? input.split('T').first : input;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sanitized)) {
        final p = sanitized.split('-');
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      }
      return DateTime.parse(input);
    } catch (_) {
      try {
        final p = input.split('/');
        if (p.length == 3) {
          return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
      } catch (_) {}
    }
    return null;
  }

  DateTime? _parseDate(String? input) => _parseAnyDate(input);
  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// --- Section Card ---
class _SectionCard extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SectionCard({required this.title, required this.children, this.initiallyExpanded = false});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E9E9E)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF444444))),
          children: widget.children,
        ),
      ),
    );
  }
}