import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/alimento.dart';

class AlimentosPlanoLocalDatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'alimentos_plano.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS alimentos_plano');
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE alimentos_plano (
        id INTEGER PRIMARY KEY,
        refeicao_id INTEGER,
        nome TEXT NOT NULL,
        grupo_alimentar TEXT NOT NULL,
        quantidade TEXT,
        calorias INTEGER,
        proteinas REAL,
        gorduras REAL,
        carboidratos REAL
      )
    ''');
  }

  /// Sobrescreve todos os alimentos armazenados (para o paciente logado).
  Future<void> salvarAlimentosPlano(List<Alimento> alimentos) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('alimentos_plano');

      for (final a in alimentos) {
        await txn.insert(
          'alimentos_plano',
          {
            'id': a.id,
            'refeicao_id': a.refeicaoId,
            'nome': a.nome,
            'grupo_alimentar': a.grupoAlimentar,
            'quantidade': a.quantidade,
            'calorias': a.calorias,
            'proteinas': a.proteinas,
            'gorduras': a.gorduras,
            'carboidratos': a.carboidratos,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Lê os alimentos armazenados localmente (modo offline).
  Future<List<Alimento>> listarAlimentosPlano() async {
    final db = await database;
    final result = await db.query('alimentos_plano');

    return result.map((row) => Alimento.fromMap(row)).toList();
  }

  Future<void> limpar() async {
    final db = await database;
    await db.delete('alimentos_plano');
  }
}
