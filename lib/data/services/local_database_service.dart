import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            nome TEXT,
            email TEXT,
            senha TEXT,
            tipo TEXT,
            telefone TEXT,
            dataNascimento TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      'user',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserByEmailAndPassword(
      String email, String senha) async {
    final db = await database;
    final result = await db.query(
      'user',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// (Opcional) Caso você queira recuperar a senha atual para regravar depois
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'user',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Atualização parcial do usuário por ID (não mexe na senha)
  Future<int> updateUserPartial({
    required int id,
    String? nome,
    String? email,
    String? telefone,
    String? dataNascimento,
    String? tipo,
  }) async {
    final db = await database;

    final data = <String, Object?>{};
    if (nome != null) data['nome'] = nome;
    if (email != null) data['email'] = email;
    if (telefone != null) data['telefone'] = telefone;
    if (dataNascimento != null) data['dataNascimento'] = dataNascimento;
    if (tipo != null) data['tipo'] = tipo;

    if (data.isEmpty) return 0;

    return await db.update(
      'user',
      data,
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> clearUser() async {
    final db = await database;
    await db.delete('user');
  }
}
