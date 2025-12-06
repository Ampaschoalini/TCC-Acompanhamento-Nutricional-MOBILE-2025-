import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/alimento.dart';

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
      version: 4, // user + alimentos_plano + nutricionista + perfil estendido
      onCreate: (db, version) async {
        // Usuário (login / perfil offline)
        await db.execute('''
          CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            nome TEXT,
            email TEXT,
            senha TEXT,
            tipo TEXT,
            telefone TEXT,
            dataNascimento TEXT,
            genero TEXT,
            objetivo TEXT,
            frequencia_exercicio_semanal TEXT,
            restricao_alimentar TEXT,
            alergia TEXT,
            observacao TEXT,
            habitos_alimentares TEXT,
            historico_familiar_doencas TEXT,
            doencas_cronicas TEXT,
            medicamentos_em_uso TEXT,
            exames_de_sangue_relevantes TEXT
          )
        ''');

        // Alimentos do plano (cache offline)
        await db.execute('''
          CREATE TABLE alimentos_plano (
            id INTEGER PRIMARY KEY,
            refeicao_id INTEGER,
            nome TEXT,
            grupo_alimentar TEXT,
            quantidade TEXT,
            calorias INTEGER,
            proteinas REAL,
            gorduras REAL,
            carboidratos REAL
          )
        ''');

        // Nutricionista (cache offline)
        await db.execute('''
          CREATE TABLE nutricionista (
            id INTEGER PRIMARY KEY,
            nome TEXT,
            email TEXT,
            celular TEXT,
            whatsapp TEXT,
            endereco TEXT,
            crn TEXT,
            especialidade TEXT,
            horarioInicio TEXT,
            horarioFim TEXT,
            diasSemanas TEXT,
            instagram TEXT,
            linkedin TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS alimentos_plano (
              id INTEGER PRIMARY KEY,
              refeicao_id INTEGER,
              nome TEXT,
              grupo_alimentar TEXT,
              quantidade TEXT,
              calorias INTEGER,
              proteinas REAL,
              gorduras REAL,
              carboidratos REAL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS nutricionista (
              id INTEGER PRIMARY KEY,
              nome TEXT,
              email TEXT,
              celular TEXT,
              whatsapp TEXT,
              endereco TEXT,
              crn TEXT,
              especialidade TEXT,
              horarioInicio TEXT,
              horarioFim TEXT,
              diasSemanas TEXT,
              instagram TEXT,
              linkedin TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          final batch = db.batch();
          batch.execute("ALTER TABLE user ADD COLUMN genero TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN objetivo TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN frequencia_exercicio_semanal TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN restricao_alimentar TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN alergia TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN observacao TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN habitos_alimentares TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN historico_familiar_doencas TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN doencas_cronicas TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN medicamentos_em_uso TEXT");
          batch.execute("ALTER TABLE user ADD COLUMN exames_de_sangue_relevantes TEXT");
          await batch.commit(noResult: true);
        }
      },
    );
  }

  // ================== USUÁRIO (LOGIN / PERFIL OFFLINE) ==================

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

  /// 🔹 novo: usado para fallback offline do perfil
  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final res = await db.query(
      'user',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> updateUserPartial({
    required int id,
    String? nome,
    String? email,
    String? telefone,
    String? dataNascimento,
    String? tipo,
    String? genero,
    String? objetivo,
    String? frequenciaExercicioSemanal,
    String? restricaoAlimentar,
    String? alergia,
    String? observacao,
    String? habitosAlimentares,
    String? historicoFamiliarDoencas,
    String? doencasCronicas,
    String? medicamentosEmUso,
    String? examesDeSangueRelevantes,
  }) async {
    final db = await database;

    final data = <String, Object?>{};
    if (nome != null) data['nome'] = nome;
    if (email != null) data['email'] = email;
    if (telefone != null) data['telefone'] = telefone;
    if (dataNascimento != null) data['dataNascimento'] = dataNascimento;
    if (tipo != null) data['tipo'] = tipo;
    if (genero != null) data['genero'] = genero;
    if (objetivo != null) data['objetivo'] = objetivo;
    if (frequenciaExercicioSemanal != null) {
      data['frequencia_exercicio_semanal'] = frequenciaExercicioSemanal;
    }
    if (restricaoAlimentar != null) {
      data['restricao_alimentar'] = restricaoAlimentar;
    }
    if (alergia != null) data['alergia'] = alergia;
    if (observacao != null) data['observacao'] = observacao;
    if (habitosAlimentares != null) {
      data['habitos_alimentares'] = habitosAlimentares;
    }
    if (historicoFamiliarDoencas != null) {
      data['historico_familiar_doencas'] = historicoFamiliarDoencas;
    }
    if (doencasCronicas != null) {
      data['doencas_cronicas'] = doencasCronicas;
    }
    if (medicamentosEmUso != null) {
      data['medicamentos_em_uso'] = medicamentosEmUso;
    }
    if (examesDeSangueRelevantes != null) {
      data['exames_de_sangue_relevantes'] = examesDeSangueRelevantes;
    }

    if (data.isEmpty) return 0;

    return await db.update(
      'user',
      data,
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updatePassword({
    required int id,
    required String senha,
  }) async {
    final db = await database;
    return await db.update(
      'user',
      {'senha': senha},
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> clearUser() async {
    final db = await database;
    await db.delete('user');
  }

  // ================== ALIMENTOS DO PLANO (CACHE OFFLINE) ==================

  Future<void> salvarAlimentosPlano(List<Alimento> alimentos) async {
    final db = await database;
    final batch = db.batch();

    batch.delete('alimentos_plano');

    for (final a in alimentos) {
      batch.insert(
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

    await batch.commit(noResult: true);
  }

  Future<List<Alimento>> getAlimentosPlano() async {
    final db = await database;
    final result = await db.query(
      'alimentos_plano',
      orderBy: 'grupo_alimentar ASC, nome ASC',
    );
    return result.map((e) => Alimento.fromMap(e)).toList();
  }

  Future<void> clearAlimentosPlano() async {
    final db = await database;
    await db.delete('alimentos_plano');
  }

  // ================== NUTRICIONISTA (CACHE OFFLINE) ==================

  Future<void> saveNutricionista(Map<String, dynamic> nutri) async {
    final db = await database;

    final rawId = nutri['id'] ?? nutri['nutricionista_id'];
    final intId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    if (intId == null) {
      return;
    }

    final row = <String, Object?>{
      'id': intId,
      'nome': nutri['nome']?.toString(),
      'email': nutri['email']?.toString(),
      'celular': nutri['celular']?.toString(),
      'whatsapp': nutri['whatsapp']?.toString(),
      'endereco': nutri['endereco']?.toString(),
      'crn': nutri['crn']?.toString(),
      'especialidade': nutri['especialidade']?.toString(),
      'horarioInicio': nutri['horarioInicio']?.toString(),
      'horarioFim': nutri['horarioFim']?.toString(),
      'diasSemanas': nutri['diasSemanas']?.toString(),
      'instagram': nutri['instagram']?.toString(),
      'linkedin': nutri['linkedin']?.toString(),
    };

    await db.insert(
      'nutricionista',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getNutricionistaById(int id) async {
    final db = await database;
    final res = await db.query(
      'nutricionista',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> clearNutricionista() async {
    final db = await database;
    await db.delete('nutricionista');
  }
}
