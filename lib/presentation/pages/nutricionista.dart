import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/nutricionista_service.dart';

class NutricionistaPage extends StatefulWidget {
  const NutricionistaPage({super.key});

  @override
  State<NutricionistaPage> createState() => _NutricionistaPageState();
}

class _NutricionistaPageState extends State<NutricionistaPage> {
  Map<String, dynamic>? nutricionista;
  bool isLoading = true;

  final NutricionistaService _service = NutricionistaService();

  @override
  void initState() {
    super.initState();
    _carregarNutricionista();
  }

  Future<void> _carregarNutricionista() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('nutricionista_id');
    // ignore: avoid_print
    print("Nutricionista ID (SharedPreferences): $id");

    if (id == null) {
      setState(() {
        isLoading = false;
        nutricionista = null;
      });
      return;
    }

    try {
      final data = await _service.getNutricionistaById(id);
      setState(() {
        nutricionista = data;
        isLoading = false;
      });
    } catch (e) {
      // Deve ser raro, já que o service captura quase tudo
      // ignore: avoid_print
      print('Erro inesperado ao carregar nutricionista: $e');
      setState(() {
        isLoading = false;
        nutricionista = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : nutricionista == null
          ? const Center(
        child: Text('Não foi possível carregar os dados.'),
      )
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFFEC8800),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC8800), Color(0xFFffb347)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: const AssetImage(
                        'assets/images/Nutricionista.jpg',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                const SizedBox(height: 12),
                _nomeEspecialidade(),
                _infoSection(
                  title: "Informações de Contato",
                  items: [
                    _infoTile(
                      Icons.email,
                      "Email",
                      nutricionista!['email']?.toString(),
                      color: Colors.green,
                    ),
                    _infoTile(
                      Icons.phone,
                      "Celular",
                      nutricionista!['celular']?.toString(),
                      color: Colors.green,
                    ),
                    _infoTile(
                      Icons.phone_android,
                      "WhatsApp",
                      _formatarWhatsapp(
                        nutricionista!['whatsapp']?.toString(),
                      ),
                      color: Colors.green,
                    ),
                    _infoTile(
                      Icons.location_on,
                      "Endereço",
                      nutricionista!['endereco']?.toString(),
                      color: Colors.green,
                    ),
                  ],
                ),
                _infoSection(
                  title: "Informações Profissionais",
                  items: [
                    _infoTile(
                      Icons.badge,
                      "CRN",
                      nutricionista!['crn']?.toString(),
                      color: const Color(0xFFEC8800),
                    ),
                    _infoTile(
                      Icons.restaurant_menu,
                      "Especialidade",
                      nutricionista!['especialidade']?.toString(),
                      color: const Color(0xFFEC8800),
                    ),
                    _infoTile(
                      Icons.access_time,
                      "Horário de Atendimento",
                      _montarHorario(),
                      color: const Color(0xFFEC8800),
                    ),
                    _infoTile(
                      Icons.calendar_today,
                      "Dias da Semana",
                      nutricionista!['diasSemanas']?.toString(),
                      color: const Color(0xFFEC8800),
                    ),
                  ],
                ),
                _infoSection(
                  title: "Informações Pessoais",
                  items: [
                    _infoTile(
                      Icons.camera_alt,
                      "Instagram",
                      nutricionista!['instagram']?.toString(),
                      color: Colors.pink,
                    ),
                    _infoTile(
                      Icons.work,
                      "LinkedIn",
                      nutricionista!['linkedin']?.toString(),
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _montarHorario() {
    final inicio = nutricionista!['horarioInicio']?.toString();
    final fim = nutricionista!['horarioFim']?.toString();
    if ((inicio == null || inicio.isEmpty) &&
        (fim == null || fim.isEmpty)) {
      return '-';
    }
    return '${inicio ?? '-'} às ${fim ?? '-'}';
  }

  Widget _nomeEspecialidade() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                nutricionista!['nome']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nutricionista!['especialidade']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> items}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  Widget _infoTile(
      IconData icon,
      String label,
      String? value, {
        Color color = Colors.black,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value == null || value.isEmpty ? '-' : value,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }

  String? _formatarWhatsapp(String? numero) {
    if (numero == null || numero.isEmpty) return null;
    final digits = numero.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11) {
      final ddd = digits.substring(0, 2);
      final digito9 = digits.substring(2, 3);
      final parte1 = digits.substring(3, 7);
      final parte2 = digits.substring(7, 11);
      return "($ddd) $digito9 $parte1-$parte2";
    }
    return numero;
  }
}
