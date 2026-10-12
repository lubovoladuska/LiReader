import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../providers/library_provider.dart';
import 'database_helper.dart';

class BackupService {
  /// Exports all books, shelves, highlights, settings, and reading sessions to a JSON file.
  static Future<void> exportBackup(BuildContext context) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final books = await db.query('books');
      final shelves = await db.query('shelves');
      final highlights = await db.query('highlights');
      final settings = await db.query('settings');
      final readingSessions = await db.query('reading_sessions');

      final backupData = {
        'version': 1,
        'appName': 'LiReader',
        'exportedAt': DateTime.now().toIso8601String(),
        'booksCount': books.length,
        'sessionsCount': readingSessions.length,
        'books': books,
        'shelves': shelves,
        'highlights': highlights,
        'settings': settings,
        'reading_sessions': readingSessions,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Save file to Downloads or Documents
      String? savedPath;
      try {
        Directory? targetDir;
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            targetDir = downloadDir;
          }
        }
        targetDir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

        final now = DateTime.now();
        final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
        final file = File('${targetDir.path}/LiReader_Backup_$timestamp.json');
        await file.writeAsString(jsonString);
        savedPath = file.path;
      } catch (e) {
        debugPrint('File write error: $e');
      }

      if (context.mounted) {
        _showExportSuccessDialog(context, jsonString, savedPath, books.length, readingSessions.length);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания резервной копии: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Imports books, shelves, highlights, settings, and reading sessions from JSON.
  static Future<void> importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      if (context.mounted) {
        await restoreFromJson(context, content);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка импорта: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Restores data directly from a JSON string.
  static Future<void> restoreFromJson(BuildContext context, String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      int booksCount = 0;
      int shelvesCount = 0;
      int highlightsCount = 0;
      int sessionsCount = 0;

      await db.transaction((txn) async {
        // 1. Shelves
        if (data['shelves'] is List) {
          for (final item in data['shelves']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('shelves', item, conflictAlgorithm: ConflictAlgorithm.replace);
              shelvesCount++;
            }
          }
        }

        // 2. Books
        if (data['books'] is List) {
          for (final item in data['books']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('books', item, conflictAlgorithm: ConflictAlgorithm.replace);
              booksCount++;
            }
          }
        }

        // 3. Highlights
        if (data['highlights'] is List) {
          for (final item in data['highlights']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('highlights', item, conflictAlgorithm: ConflictAlgorithm.replace);
              highlightsCount++;
            }
          }
        }

        // 4. Reading Sessions
        if (data['reading_sessions'] is List) {
          for (final item in data['reading_sessions']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('reading_sessions', item, conflictAlgorithm: ConflictAlgorithm.replace);
              sessionsCount++;
            }
          }
        }

        // 5. Settings
        if (data['settings'] is List) {
          for (final item in data['settings']) {
            if (item is Map<String, dynamic>) {
              await txn.insert('settings', item, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      });

      // Reload LibraryProvider
      if (context.mounted) {
        final library = context.read<LibraryProvider>();
        await library.loadLibrary();

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Данные восстановлены!'),
                ],
              ),
              content: Text(
                'Успешно импортировано:\n'
                '• Книг: $booksCount\n'
                '• Полок: $shelvesCount\n'
                '• Сессий статистики: $sessionsCount\n'
                '• Заметок: $highlightsCount',
                style: const TextStyle(height: 1.5),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отлично'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Неверный формат резервной копии: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static void _showExportSuccessDialog(
    BuildContext context,
    String jsonString,
    String? savedPath,
    int booksCount,
    int sessionsCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Бэкап готов!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сохранено $booksCount книг и $sessionsCount сессий чтения.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (savedPath != null) ...[
              const Text('Файл сохранён по пути:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  savedPath,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Для 100% надежности вы также можете скопировать весь текст резервной копии в буфер обмена:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Скопировать JSON в буфер'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Резервная копия скопирована в буфер обмена!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
