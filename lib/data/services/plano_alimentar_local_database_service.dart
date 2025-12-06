import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/dieta.dart';

class PlanoAlimentarLocalDatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'plano_alimentar.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plano_alimentar (
            paciente_id INTEGER PRIMARY KEY,
            json TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Salva o plano alimentar completo (lista de dietas) para um paciente.
  Future<void> salvarPlano(int pacienteId, List<Dieta> dietas) async {
    final db = await database;

    final jsonStr = jsonEncode(
      dietas.map((d) => d.toJson()).toList(),
    );

    await db.insert(
      'plano_alimentar',
      {
        'paciente_id': pacienteId,
        'json': jsonStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lê o plano alimentar salvo localmente.
  Future<List<Dieta>> getPlano(int pacienteId) async {
    final db = await database;
    final res = await db.query(
      'plano_alimentar',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      limit: 1,
    );

    if (res.isEmpty) return <Dieta>[];

    final rawJson = res.first['json'];
    if (rawJson == null) return <Dieta>[];

    try {
      final decoded = jsonDecode(rawJson as String) as List<dynamic>;
      return decoded
          .map((e) => Dieta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <Dieta>[];
    }
  }

  Future<void> clearPlano(int pacienteId) async {
    final db = await database;
    await db.delete(
      'plano_alimentar',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
    );
  }
}
