import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dieta.dart';

class DietaService {
  // Para emulador Android use 10.0.2.2 | para dispositivo físico, use o IP da sua máquina
  final String baseUrl = "http://10.0.2.2:8800/dieta/getDietaByPacienteId";

  Future<List<Dieta>> getDietasByPacienteId(int pacienteId) async {
    final response = await http.get(Uri.parse("$baseUrl/$pacienteId"));

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((d) => Dieta.fromJson(d)).toList();
    } else {
      throw Exception("Erro ao carregar dietas: ${response.statusCode}");
    }
  }
}
