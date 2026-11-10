import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/date_x.dart';
import '../local/hive_store.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// JSON export/import of every Hive box.
class BackupService {
  static const _format = 'forkcast-backup';
  static const _version = 1;

  Map<String, dynamic> buildSnapshot() {
    final boxes = <String, Map<String, dynamic>>{};
    for (final name in HiveStore.allBoxes) {
      final box = HiveStore.box(name);
      boxes[name] = {
        for (final key in box.keys) key.toString(): jsonDecode(box.get(key)!),
      };
    }
    return {
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes,
    };
  }

  /// Writes a backup file and opens the share sheet. Returns the file path.
  Future<String> exportAndShare() async {
    final json = const JsonEncoder.withIndent('  ').convert(buildSnapshot());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nibbl-backup-${DateTime.now().dayKey}.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'Nibbl backup'),
    );
    return file.path;
  }

  /// Lets the user pick a backup file. Returns parsed snapshot or null if cancelled.
  Future<Map<String, dynamic>?> pickBackup() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return null;
    final content = await files.first.xFile.readAsString();
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const BackupException('That file isn\'t valid JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != _format || decoded['boxes'] is! Map) {
      throw const BackupException('That file isn\'t a Nibbl backup.');
    }
    return decoded;
  }

  /// Replaces all local data with [snapshot].
  Future<void> restore(Map<String, dynamic> snapshot) async {
    final boxes = Map<String, dynamic>.from(snapshot['boxes'] as Map);
    for (final name in HiveStore.allBoxes) {
      final box = HiveStore.box(name);
      await box.clear();
      final data = boxes[name];
      if (data is Map) {
        await box.putAll({for (final e in data.entries) e.key.toString(): jsonEncode(e.value)});
      }
    }
  }

  Future<void> wipeAll() async {
    for (final name in HiveStore.allBoxes) {
      await HiveStore.box(name).clear();
    }
  }
}
