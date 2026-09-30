import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// One pasted line, as the server read it.
class ImportRow {
  const ImportRow({
    required this.line,
    required this.name,
    required this.price,
    required this.category,
    required this.action,
    this.error,
  });

  final int line;
  final String name;
  final double? price;
  final String category;

  /// `create`, `update` or `error`.
  final String action;

  /// `no_name`, `bad_price`, `name_too_long` or `too_many_rows`.
  final String? error;

  factory ImportRow.fromJson(Map<String, dynamic> json) => ImportRow(
    line: (json['line'] as num).toInt(),
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble(),
    category: json['category'] as String? ?? '',
    action: json['action'] as String? ?? 'error',
    error: json['error'] as String?,
  );
}

class ImportResult {
  const ImportResult({
    required this.applied,
    required this.created,
    required this.updated,
    required this.errors,
    required this.rows,
  });

  final bool applied;
  final int created;
  final int updated;
  final int errors;
  final List<ImportRow> rows;

  factory ImportResult.fromJson(Map<String, dynamic> json) => ImportResult(
    applied: json['applied'] as bool? ?? false,
    created: (json['created'] as num?)?.toInt() ?? 0,
    updated: (json['updated'] as num?)?.toInt() ?? 0,
    errors: (json['errors'] as num?)?.toInt() ?? 0,
    rows: [
      for (final r in (json['rows'] as List? ?? const []))
        ImportRow.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
  );
}

/// A whole menu from rows copied out of a spreadsheet. The server parses; the
/// app only shows what it understood and asks before anything is written.
class MenuImportRepository {
  MenuImportRepository(this._dio);

  final Dio _dio;

  Future<ImportResult> run(
    int restaurantId,
    String text, {
    required bool dryRun,
  }) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/menu/import',
      data: {'text': text, 'dry_run': dryRun},
    );
    return ImportResult.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final menuImportRepositoryProvider = Provider(
  (ref) => MenuImportRepository(ref.watch(dioProvider)),
);
