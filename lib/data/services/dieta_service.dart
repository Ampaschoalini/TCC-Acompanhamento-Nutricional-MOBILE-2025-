import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dieta.dart';

class DietaService {
  // Para emulador Android use 10.0.2.2 | para dispositivo físico, use o IP da sua máquina
  final String baseUrl = "http://10.0.2.2:8800/dieta/getDietaByPacienteId";

  Future<List<Dieta>> getDietasByPacienteId(int pacienteId) async {
    try {
      final uri = Uri.parse("$baseUrl/$pacienteId");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((d) => Dieta.fromJson(d)).toList();
      } else {
        // Erro HTTP (500, 404, etc) → não derruba o app, só loga e devolve lista vazia
        // ignore: avoid_print
        print(
          "Erro HTTP em getDietasByPacienteId: "
              "status=${response.statusCode} body=${response.body}",
        );
        return <Dieta>[];
      }
    } catch (e) {
      // Aqui pega "Connection failed", timeout, etc.
      // Em vez de propagar a exceção, devolvemos lista vazia
      // ignore: avoid_print
      print("Erro de conexão em getDietasByPacienteId: $e");
      return <Dieta>[];
    }
  }
}
