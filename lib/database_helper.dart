import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'offline_lms_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE classes (
        class_code TEXT PRIMARY KEY,
        class_name TEXT NOT NULL,
        teacher_email TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_email TEXT NOT NULL,
        class_code TEXT NOT NULL,
        class_name TEXT NOT NULL,
        FOREIGN KEY (class_code) REFERENCES classes (class_code) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_code TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        file_path TEXT NOT NULL,
        FOREIGN KEY (class_code) REFERENCES classes (class_code) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quizzes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_code TEXT NOT NULL,
        question TEXT NOT NULL,
        option_A TEXT NOT NULL,
        option_B TEXT NOT NULL,
        option_C TEXT NOT NULL,
        option_D TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        FOREIGN KEY (class_code) REFERENCES classes (class_code) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_code TEXT NOT NULL,
        student_email TEXT NOT NULL,
        student_name TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        submitted_at TEXT NOT NULL,
        FOREIGN KEY (class_code) REFERENCES classes (class_code) ON DELETE CASCADE
      )
    ''');
  }

  // ══════════════════════════════════════════
  // 1. AUTH
  // ══════════════════════════════════════════

  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await database;
    try {
      await db.insert('users', {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role.trim(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>?> authenticateUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await database;
    String cleanEmail = email.trim().toLowerCase();
    String cleanRole = role.trim();

    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password = ? AND role = ?',
      whereArgs: [cleanEmail, password, cleanRole],
    );

    if (maps.isNotEmpty) {
      Map<String, String> authenticatedUser = {
        'name': maps.first['name'].toString(),
        'email': maps.first['email'].toString(),
        'password': maps.first['password'].toString(),
        'role': maps.first['role'].toString(),
      };
      await setCurrentUserSession(authenticatedUser);
      return authenticatedUser;
    }
    return null;
  }

  Future<bool> updatePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> check = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, currentPassword],
    );

    if (check.isEmpty) {
      return false;
    }

    int rowsAffected = await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );

    if (rowsAffected > 0) {
      final currentSession = await getCurrentUserSession();
      if (currentSession != null && currentSession['email'] == email) {
        currentSession['password'] = newPassword;
        await setCurrentUserSession(currentSession);
      }
      return true;
    }
    return false;
  }

  Future<bool> updateUserProfile({
    required String email,
    required String newName,
  }) async {
    final db = await database;

    if (newName.trim().isEmpty) return false;

    try {
      int rowsAffected = await db.update(
        'users',
        {'name': newName.trim()},
        where: 'email = ?',
        whereArgs: [email],
      );

      if (rowsAffected > 0) {
        final currentSession = await getCurrentUserSession();
        if (currentSession != null && currentSession['email'] == email) {
          currentSession['name'] = newName.trim();
          await setCurrentUserSession(currentSession);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating profile: $e");
      return false;
    }
  }

  Future<void> setCurrentUserSession(Map<String, String>? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove('current_user_session');
    } else {
      await prefs.setString('current_user_session', jsonEncode(user));
    }
  }

  Future<Map<String, String>?> getCurrentUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? userStr = prefs.getString('current_user_session');
    if (userStr == null) return null;
    Map<String, dynamic> decoded = jsonDecode(userStr);
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_session');
  }

  Future<void> close() async {
    await setCurrentUserSession(null);
  }

  // ══════════════════════════════════════════
  // 2. CLASSES — SQLite + Firestore sync
  // ══════════════════════════════════════════

  Future<String> createClass(String className, String teacherEmail) async {
    final db = await database;
    const chars = 'ABCDEFGHJKLMNOPQRSTUVWXYZ23456789';
    Random rnd = Random();
    String classCode = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );

    await db.insert('classes', {
      'class_code': classCode,
      'class_name': className,
      'teacher_email': teacherEmail,
    });

    try {
      await _firestore.collection('classes').doc(classCode).set({
        'class_code': classCode,
        'class_name': className,
        'teacher_email': teacherEmail,
        'created_at': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Firestore sync failed (offline ayaa u badan): $e");
    }

    return classCode;
  }

  Future<List<Map<String, String>>> getTeacherClasses(String teacherEmail) async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query(
      'classes',
      where: 'teacher_email = ?',
      whereArgs: [teacherEmail],
    );
    return res
        .map((item) => item.map((key, value) => MapEntry(key, value.toString())))
        .toList();
  }

  Future<void> deleteClass(String classCode) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('materials', where: 'class_code = ?', whereArgs: [classCode]);
      await txn.delete('enrollments', where: 'class_code = ?', whereArgs: [classCode]);
      await txn.delete('quizzes', where: 'class_code = ?', whereArgs: [classCode]);
      await txn.delete('quiz_results', where: 'class_code = ?', whereArgs: [classCode]);
      await txn.delete('classes', where: 'class_code = ?', whereArgs: [classCode]);
    });

    try {
      await _firestore.collection('classes').doc(classCode).delete().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Firestore delete failed: $e");
    }
  }

  Future<bool> joinClassWithCode(String classCode, String studentEmail) async {
    final db = await database;
    String cleanCode = classCode.toUpperCase().trim();

    List<Map<String, dynamic>> classCheck = await db.query(
      'classes',
      where: 'class_code = ?',
      whereArgs: [cleanCode],
    );

    String? className;

    if (classCheck.isNotEmpty) {
      className = classCheck.first['class_name'].toString();
    } else {
      try {
        final doc = await _firestore.collection('classes').doc(cleanCode).get().timeout(const Duration(seconds: 5));
        if (doc.exists) {
          final data = doc.data()!;
          className = data['class_name'] as String;
          await db.insert('classes', {
            'class_code': cleanCode,
            'class_name': className,
            'teacher_email': data['teacher_email'] ?? '',
          });
        }
      } catch (e) {
        debugPrint("Firestore lookup failed: $e");
      }
    }

    if (className == null) return false;

    List<Map<String, dynamic>> enrollCheck = await db.query(
      'enrollments',
      where: 'student_email = ? AND class_code = ?',
      whereArgs: [studentEmail, cleanCode],
    );
    if (enrollCheck.isNotEmpty) return true;

    await db.insert('enrollments', {
      'student_email': studentEmail,
      'class_code': cleanCode,
      'class_name': className,
    });

    return true;
  }

  Future<List<Map<String, String>>> getStudentClasses(String studentEmail) async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query(
      'enrollments',
      where: 'student_email = ?',
      whereArgs: [studentEmail],
    );
    return res
        .map((item) => item.map((key, value) => MapEntry(key, value.toString())))
        .toList();
  }

  Future<int> getStudentCountByClass(String classCode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM enrollments WHERE class_code = ?',
      [classCode],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ✅ CUSUB — Liiska Ardayda ee Class-ka (magaca oo keliya, email lama tusin)
  Future<List<Map<String, String>>> getStudentsInClass(String classCode) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT users.name as student_name, enrollments.class_name as class_name
      FROM enrollments
      INNER JOIN users ON enrollments.student_email = users.email
      WHERE enrollments.class_code = ?
    ''', [classCode]);

    return result.map((row) => {
      'student_name': row['student_name']?.toString() ?? 'Unknown',
      'class_name': row['class_name']?.toString() ?? '',
    }).toList();
  }

  // ✅ CUSUB — Liiska Ardayda ee Macallinka oo Dhan (class-yada oo dhan)
  Future<List<Map<String, String>>> getAllStudentsForTeacher(String teacherEmail) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT users.name as student_name, enrollments.class_name as class_name, enrollments.class_code as class_code
      FROM enrollments
      INNER JOIN users ON enrollments.student_email = users.email
      INNER JOIN classes ON enrollments.class_code = classes.class_code
      WHERE classes.teacher_email = ?
      ORDER BY enrollments.class_name ASC, users.name ASC
    ''', [teacherEmail]);

    return result.map((row) => {
      'student_name': row['student_name']?.toString() ?? 'Unknown',
      'class_name': row['class_name']?.toString() ?? '',
      'class_code': row['class_code']?.toString() ?? '',
    }).toList();
  }

  // ══════════════════════════════════════════
  // 3. MATERIALS — SQLite + Firestore metadata sync
  // ══════════════════════════════════════════

  Future<int> addMaterial({
    required String classCode,
    required String title,
    required String description,
    required String filePath,
  }) async {
    try {
      final db = await database;
      int id = await db.insert('materials', {
        'class_code': classCode,
        'title': title,
        'description': description,
        'file_path': filePath,
      });

      try {
        await _firestore
            .collection('classes')
            .doc(classCode)
            .collection('materials')
            .add({
          'title': title,
          'description': description,
          'created_at': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("Firestore material sync failed: $e");
      }

      return id;
    } catch (e) {
      debugPrint("Error inserting material: $e");
      return -1;
    }
  }

  Future<List<Map<String, String>>> getClassMaterials(String classCode) async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query(
      'materials',
      where: 'class_code = ?',
      whereArgs: [classCode],
    );
    return res
        .map((item) => item.map((key, value) => MapEntry(key, value.toString())))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMaterialsByClass(String classCode) async {
    final db = await database;
    final result = await db.query(
      'materials',
      where: 'class_code = ?',
      whereArgs: [classCode],
      orderBy: 'id DESC',
    );
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteMaterial(int materialId) async {
    final db = await database;
    await db.delete('materials', where: 'id = ?', whereArgs: [materialId]);
  }

  // ══════════════════════════════════════════
  // 4. QUIZZES — SQLite + Firestore sync
  // ══════════════════════════════════════════

  Future<void> addQuizQuestion({
    required String classCode,
    required String quizTitle,
    required String sectionName,
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctAnswer,
  }) async {
    final db = await database;
    await db.insert('quizzes', {
      'class_code': classCode,
      'question': question,
      'option_A': optionA,
      'option_B': optionB,
      'option_C': optionC,
      'option_D': optionD,
      'correct_answer': correctAnswer,
    });

    try {
      await _firestore
          .collection('classes')
          .doc(classCode)
          .collection('quizzes')
          .add({
        'question': question,
        'option_A': optionA,
        'option_B': optionB,
        'option_C': optionC,
        'option_D': optionD,
        'correct_answer': correctAnswer,
        'created_at': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Firestore quiz sync failed: $e");
    }
  }

  Future<List<Map<String, String>>> getClassQuizzes(String classCode) async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query(
      'quizzes',
      where: 'class_code = ?',
      whereArgs: [classCode],
    );
    return res
        .map((item) => item.map((key, value) => MapEntry(key, value.toString())))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getQuizQuestionsByClass(String classCode) async {
    final db = await database;
    final result = await db.query(
      'quizzes',
      where: 'class_code = ?',
      whereArgs: [classCode],
      orderBy: 'id ASC',
    );
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ══════════════════════════════════════════
  // 5. QUIZ RESULTS — Ardayga jawaabihiisa + macallinka view-kiisa
  // ══════════════════════════════════════════

  // ✅ SAXITAAN — Firestore call-ka hadda wuxuu leeyahay timeout 5 sec,
  // si quiz-ku uusan u sii wareegsanaan (infinite loading) haddii
  // internet la'aan jirto ama Firestore uu raagayo
  Future<void> submitQuizResult({
    required String classCode,
    required String studentEmail,
    required String studentName,
    required int score,
    required int totalQuestions,
  }) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    // SQLite write — waxaa marwalba la sameeyaa, offline-na wuu shaqeeyaa
    await db.insert('quiz_results', {
      'class_code': classCode,
      'student_email': studentEmail,
      'student_name': studentName,
      'score': score,
      'total_questions': totalQuestions,
      'submitted_at': timestamp,
    });

    // Firestore write — leh timeout, si uusan u joojin natiijada haddii
    // internet la'aan jirto ama uu raagayo
    try {
      await _firestore
          .collection('classes')
          .doc(classCode)
          .collection('quiz_results')
          .add({
        'student_email': studentEmail,
        'student_name': studentName,
        'score': score,
        'total_questions': totalQuestions,
        'submitted_at': timestamp,
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Firestore quiz result sync failed (offline ayaa u badan): $e");
    }
  }

  Future<List<Map<String, dynamic>>> getQuizResultsByClass(String classCode) async {
    final db = await database;
    final result = await db.query(
      'quiz_results',
      where: 'class_code = ?',
      whereArgs: [classCode],
      orderBy: 'submitted_at DESC',
    );
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<bool> hasStudentTakenQuiz(String classCode, String studentEmail) async {
    final db = await database;
    final result = await db.query(
      'quiz_results',
      where: 'class_code = ? AND student_email = ?',
      whereArgs: [classCode, studentEmail],
    );
    return result.isNotEmpty;
  }

  // ══════════════════════════════════════════
  // 6. FIRESTORE SYNC — Soo qaadasho casharro/quiz Firestore-ka
  // ══════════════════════════════════════════

  Future<void> syncClassFromFirestore(String classCode) async {
    final db = await database;
    try {
      final materialsSnapshot = await _firestore
          .collection('classes')
          .doc(classCode)
          .collection('materials')
          .get()
          .timeout(const Duration(seconds: 8));

      for (final doc in materialsSnapshot.docs) {
        final data = doc.data();
        final existing = await db.query(
          'materials',
          where: 'class_code = ? AND title = ?',
          whereArgs: [classCode, data['title']],
        );
        if (existing.isEmpty) {
          await db.insert('materials', {
            'class_code': classCode,
            'title': data['title'] ?? '',
            'description': data['description'] ?? '',
            'file_path': '',
          });
        }
      }

      final quizSnapshot = await _firestore
          .collection('classes')
          .doc(classCode)
          .collection('quizzes')
          .get()
          .timeout(const Duration(seconds: 8));

      for (final doc in quizSnapshot.docs) {
        final data = doc.data();
        final existing = await db.query(
          'quizzes',
          where: 'class_code = ? AND question = ?',
          whereArgs: [classCode, data['question']],
        );
        if (existing.isEmpty) {
          await db.insert('quizzes', {
            'class_code': classCode,
            'question': data['question'] ?? '',
            'option_A': data['option_A'] ?? '',
            'option_B': data['option_B'] ?? '',
            'option_C': data['option_C'] ?? '',
            'option_D': data['option_D'] ?? '',
            'correct_answer': data['correct_answer'] ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint("Firestore class sync failed (offline ayaa u badan): $e");
    }
  }
}