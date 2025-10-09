import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/dieta.dart';
import '../../data/services/dieta_service.dart';
import '../../data/models/alimento.dart';

// ============ Constantes de tema (escopo global) ============
const Color kPrimary = Color(0xFFEC8800);
const Color kBg = Color(0xFFF5F5F5);
const Color kText = Color(0xFF444444);

class AlimentosPlanoPage extends StatefulWidget {
  const AlimentosPlanoPage({super.key});

  @override
  State<AlimentosPlanoPage> createState() => _AlimentosPlanoPageState();
}

class _AlimentosPlanoPageState extends State<AlimentosPlanoPage> {
  final DietaService _service = DietaService();
  Future<List<Dieta>>? _dietasFuture;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static const List<String> gruposFixos = [
    'Grãos',
    'Frutas',
    'Cereais',
    'Massas',
    'Açúcares e Doces',
  ];

  // ====== Normalização e mapeamento de grupo ======
  String _normalize(String s) {
    final lower = s.toLowerCase().trim();
    const mapa = {
      'á':'a','à':'a','â':'a','ã':'a','ä':'a',
      'é':'e','è':'e','ê':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i',
      'ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
      'ú':'u','ù':'u','û':'u','ü':'u',
      'ç':'c'
    };
    final sb = StringBuffer();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      sb.write(mapa[ch] ?? ch);
    }
    final basic = sb.toString();
    // remove pontuação e substitui separadores por espaço
    final cleaned = basic
        .replaceAll(RegExp(r'[/|&,+;]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  // Retorna o grupo canônico com base em regex flexíveis
  String? _canonicalizeGrupo(String? g) {
    if (g == null || g.trim().isEmpty) return null;
    final s = _normalize(g);

    // 1) Açúcares e Doces
    if (RegExp(r'\bacucar(es)?\b').hasMatch(s) || RegExp(r'\bdoce(s)?\b').hasMatch(s)) {
      return 'Açúcares e Doces';
    }

    // 2) Grãos
    if (RegExp(r'\bgrao(s)?\b').hasMatch(s)) {
      return 'Grãos';
    }

    // 3) Cereais
    if (RegExp(r'\bcereal(is)?\b').hasMatch(s)) {
      return 'Cereais';
    }

    // 4) Frutas
    if (RegExp(r'\bfruta(s)?\b').hasMatch(s)) {
      return 'Frutas';
    }

    // 5) Massas
    if (RegExp(r'\bmassa(s)?\b').hasMatch(s) ||
        RegExp(r'\bmacarrao\b').hasMatch(s) ||
        RegExp(r'\bespaguete\b').hasMatch(s) ||
        RegExp(r'\bpenne\b').hasMatch(s) ||
        RegExp(r'\btalharim\b').hasMatch(s) ||
        RegExp(r'\bfusilli\b').hasMatch(s)) {
      return 'Massas';
    }

    // Casos com ordem trocada
    if (s.contains('acucar') && s.contains('doce')) {
      return 'Açúcares e Doces';
    }

    if (s.contains('cereal')) return 'Cereais';
    if (s.contains('grao')) return 'Grãos';

    return null;
  }

  // Ícone por grupo (Material disponível em versões estáveis)
  IconData _iconForGroup(String g) {
    switch (g) {
      case 'Frutas':
        return Icons.apple;
      case 'Massas':
        return Icons.ramen_dining;
      case 'Cereais':
        return Icons.breakfast_dining;
      case 'Grãos':
        return Icons.eco;
      case 'Açúcares e Doces':
        return Icons.icecream;
      default:
        return Icons.local_dining;
    }
  }

  // Cor suave por grupo (harmônica ao laranja)
  Color _tintForGroup(String g) {
    switch (g) {
      case 'Frutas':
        return const Color(0xFFFFF0E0);
      case 'Massas':
        return const Color(0xFFFFF5E8);
      case 'Cereais':
        return const Color(0xFFFFF7EC);
      case 'Grãos':
        return const Color(0xFFFFEFE0);
      case 'Açúcares e Doces':
        return const Color(0xFFFFF1E6);
      default:
        return Colors.white;
    }
  }

  // Agrupa por grupo fixo e ordena
  Map<String, List<Alimento>> _agruparEOrdenar(List<Alimento> alimentos) {
    final filtrados = _query.isEmpty
        ? alimentos
        : alimentos.where((a) => a.nome.toLowerCase().contains(_query)).toList();

    final Map<String, List<Alimento>> porGrupo = {
      for (final g in gruposFixos) g: <Alimento>[],
    };

    for (final a in filtrados) {
      final can = _canonicalizeGrupo(a.grupoAlimentar);
      if (can != null && porGrupo.containsKey(can)) {
        porGrupo[can]!.add(a);
      }
    }

    for (final entry in porGrupo.entries) {
      entry.value.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    }

    return porGrupo;
  }

  @override
  void initState() {
    super.initState();
    carregarPlanos();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  Future<void> carregarPlanos() async {
    final prefs = await SharedPreferences.getInstance();
    final pacienteId = prefs.getInt('paciente_id') ?? 0;
    setState(() {
      _dietasFuture = _service.getDietasByPacienteId(pacienteId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF2E6), kBg],
          ),
        ),
        child: FutureBuilder<List<Dieta>>(
          future: _dietasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _EmptyState(
                icon: Icons.error_outline,
                title: 'Algo deu errado',
                subtitle: 'Não foi possível carregar seus planos.\n${snapshot.error}',
                onRetry: carregarPlanos,
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const _EmptyState(
                icon: Icons.restaurant_menu,
                title: 'Nenhum plano encontrado',
                subtitle: 'Quando seu nutricionista publicar um plano,\neles aparecerão aqui.',
              );
            }

            final alimentos = snapshot.data!
                .expand((dieta) => dieta.refeicoes)
                .expand((refeicao) => refeicao.alimentos)
                .toList();

            if (alimentos.isEmpty) {
              return const _EmptyState(
                icon: Icons.food_bank_outlined,
                title: 'Sem alimentos cadastrados',
                subtitle: 'Os alimentos do seu plano aparecerão aqui.',
              );
            }

            final agrupado = _agruparEOrdenar(alimentos);
            final totalItens = agrupado.values.fold<int>(0, (acc, l) => acc + l.length);

            return RefreshIndicator(
              onRefresh: carregarPlanos,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SearchBar(
                        controller: _searchCtrl,
                        hint: 'Pesquisar alimento...',
                        onClear: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _query.isEmpty
                                  ? 'Grupos alimentares (fixos)'
                                  : 'Resultados para "${_searchCtrl.text}"',
                              style: const TextStyle(
                                color: kText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (totalItens == 0)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('Nenhum alimento encontrado.'),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: gruposFixos.length,
                      itemBuilder: (context, index) {
                        final grupo = gruposFixos[index];
                        final itens = agrupado[grupo] ?? const <Alimento>[];
                        if (itens.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: _GroupCard(
                            title: grupo,
                            items: itens,
                            primary: kPrimary,
                            textColor: kText,
                            icon: _iconForGroup(grupo),
                            tint: _tintForGroup(grupo),
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "Alimentos dos Planos",
        style: TextStyle(
          color: kText,
          fontWeight: FontWeight.w800,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimary, Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Ordenar',
          onPressed: () {
            // ponto de extensão para ordenar por kcal, nome, etc.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Em breve: ordenar resultados')),
            );
          },
          icon: const Icon(Icons.sort, color: Colors.white),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;
  const _SearchBar({required this.controller, required this.hint, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }
}



class _GroupCard extends StatefulWidget {
  final String title;
  final List<Alimento> items;
  final Color primary;
  final Color textColor;
  final IconData icon;
  final Color tint;

  const _GroupCard({
    required this.title,
    required this.items,
    required this.primary,
    required this.textColor,
    required this.icon,
    required this.tint,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: widget.tint,
          collapsedBackgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = widget.items[i];
                return _AlimentoTile(
                  alimento: a,
                  primary: widget.primary,
                  textColor: widget.textColor,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AlimentoTile extends StatelessWidget {
  final Alimento alimento;
  final Color primary;
  final Color textColor;
  const _AlimentoTile({required this.alimento, required this.primary, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final leadingLetter = alimento.nome.isNotEmpty ? alimento.nome.characters.first.toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: primary.withOpacity(0.12),
        child: Text(
          leadingLetter,
          style: TextStyle(color: primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        alimento.nome,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _subtitle(alimento),
        style: TextStyle(color: textColor.withOpacity(0.8)),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${alimento.calorias} kcal',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      onTap: () {
        // future: abrir detalhes do alimento
      },
    );
  }

  String _subtitle(Alimento a) {
    final grp = a.grupoAlimentar;
    final base = (grp.isNotEmpty) ? grp : 'Alimento';
    final hasQtd = a.quantidade.isNotEmpty;
    return hasQtd ? '$base • ${a.quantidade}' : base;
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRetry;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline, size: 38, color: kPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kText.withOpacity(0.8),
                height: 1.3,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
