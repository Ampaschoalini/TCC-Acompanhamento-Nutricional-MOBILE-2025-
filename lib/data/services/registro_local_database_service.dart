import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RegistroLocalDatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'registro_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE registro_offline (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            paciente_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Salva um payload de atualização pendente (quando está offline).
  Future<void> addPendingUpdate(int pacienteId, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(
      'registro_offline',
      {
        'paciente_id': pacienteId,
        'created_at': DateTime.now().toIso8601String(),
        'payload': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Busca todos os updates pendentes para o paciente, em ordem cronológica.
  Future<List<Map<String, dynamic>>> getPendingUpdates(int pacienteId) async {
    final db = await database;
    final res = await db.query(
      'registro_offline',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
      orderBy: 'created_at ASC, id ASC',
    );
    return res;
  }

  /// Remove um update específico (após sincronizar com o backend).
  Future<void> deleteUpdate(int id) async {
    final db = await database;
    await db.delete(
      'registro_offline',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Limpa todos os updates pendentes de um paciente (se você quiser em algum momento).
  Future<void> clearAllForPaciente(int pacienteId) async {
    final db = await database;
    await db.delete(
      'registro_offline',
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
    );
  }
}
