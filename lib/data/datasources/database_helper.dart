/* import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alimento.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'alimentos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE alimentos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT,
      calorias INTEGER,
      proteinas REAL,
      gorduras REAL,
      carboidratos REAL
    )
  ''');

    await db.execute('''
    CREATE TABLE dieta (
      id INTEGER PRIMARY KEY,
      paciente_id INTEGER,
      descricao TEXT,
      status TEXT
    )
  ''');

    // Inserção de alimentos (mantido)
    await db.insert('alimentos', {
      'nome': 'Banana',
      'calorias': 89,
      'proteinas': 1.1,
      'gorduras': 0.3,
      'carboidratos': 22.8,
    });

    await db.insert('alimentos', {
      'nome': 'Arroz',
      'calorias': 130,
      'proteinas': 2.7,
      'gorduras': 0.3,
      'carboidratos': 28.2,
    });

    await db.insert('alimentos', {
      'nome': 'Frango grelhado',
      'calorias': 165,
      'proteinas': 31.0,
      'gorduras': 3.6,
      'carboidratos': 0.0,
    });
  }

  Future<List<Alimento>> getAlimentos({String? filtro}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (filtro != null && filtro.isNotEmpty) {
      maps = await db.query(
        'alimentos',
        where: 'nome LIKE ?',
        whereArgs: ['%$filtro%'],
      );
    } else {
      maps = await db.query('alimentos');
    }

    return maps.map((map) => Alimento.fromMap(map)).toList();
  }
}
*/