import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/dieta.dart';
import '../data/models/alimento.dart';

class DietaScreen extends StatefulWidget {
  final Dieta dieta;
  const DietaScreen({super.key, required this.dieta});

  @override
  State<DietaScreen> createState() => _DietaScreenState();
}

class _DietaScreenState extends State<DietaScreen> {
  final Set<int> alimentosConsumidos = {};

  Future<void> atualizarKcal(Alimento alimento, bool consumido) async {
    final prefs = await SharedPreferences.getInstance();
    int atual = prefs.getInt('kcal_consumidas') ?? 0;

    if (consumido) {
      atual += alimento.calorias;
      alimentosConsumidos.add(alimento.id);
    } else {
      atual -= alimento.calorias;
      alimentosConsumidos.remove(alimento.id);
    }

    await prefs.setInt('kcal_consumidas', atual);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do plano
        Text(
          widget.dieta.nome,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.dieta.objetivo,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "De ${widget.dieta.dataInicio} até ${widget.dieta.dataTermino}",
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
        const Divider(height: 20, thickness: 1),

        // Lista de refeições
        ...widget.dieta.refeicoes.map((refeicao) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                refeicao.tipoRefeicao, // exemplo: Café da Manhã, Almoço...
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEC8800),
                ),
              ),
              const SizedBox(height: 6),
              ...refeicao.alimentos.map((alimento) {
                return CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(alimento.nome),
                  subtitle: Text(
                    "${alimento.quantidade} • ${alimento.calorias} kcal",
                  ),
                  value: alimentosConsumidos.contains(alimento.id),
                  onChanged: (bool? value) {
                    atualizarKcal(alimento, value ?? false);
                  },
                );
              }),
              const Divider(height: 20, thickness: 0.7),
            ],
          );
        }),
      ],
    );
  }
}
