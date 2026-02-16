import "package:mysql_client/mysql_client.dart";

import "../../core/config/app_config.dart";
import "../models/sync_payload.dart";

class MySqlProgressService {
  bool _schemaReady = false;

  Future<Map<String, SyncBookEntry>> fetchUserProgress({
    required String userEmail,
  }) async {
    final String normalizedUser = _normalizeUser(userEmail);
    if (normalizedUser.isEmpty) {
      return <String, SyncBookEntry>{};
    }

    return _withConnection((conn) async {
      await _ensureSchema(conn);

      final IResultSet result = await conn.execute(
        '''
        SELECT drive_file_id, cfi, chapter, percent, updated_at_ms
        FROM book_progress
        WHERE user_email = :user_email
        ''',
        <String, dynamic>{"user_email": normalizedUser},
      );

      final Map<String, SyncBookEntry> progress = <String, SyncBookEntry>{};

      for (final ResultSetRow row in result.rows) {
        final String fileId = (row.colByName("drive_file_id") ?? "").trim();
        if (fileId.isEmpty) {
          continue;
        }

        final int ts = int.tryParse(row.colByName("updated_at_ms") ?? "") ?? 0;
        final int? chapter = int.tryParse(row.colByName("chapter") ?? "");
        final double? percent = double.tryParse(row.colByName("percent") ?? "");

        progress[fileId] = SyncBookEntry(
          cfi: (row.colByName("cfi") ?? "").trim(),
          ts: ts,
          chapter: chapter,
          percent: percent,
        );
      }

      return progress;
    });
  }

  Future<void> upsertUserProgress({
    required String userEmail,
    required Map<String, SyncBookEntry> entries,
    required String deviceName,
  }) async {
    final String normalizedUser = _normalizeUser(userEmail);
    if (normalizedUser.isEmpty || entries.isEmpty) {
      return;
    }

    final String safeDevice = deviceName.trim().isEmpty
        ? "Flutter"
        : deviceName.trim();

    await _withConnection((conn) async {
      await _ensureSchema(conn);

      await conn.transactional((tx) async {
        for (final MapEntry<String, SyncBookEntry> item in entries.entries) {
          final String fileId = item.key.trim();
          if (fileId.isEmpty) {
            continue;
          }

          final SyncBookEntry entry = item.value;
          final int ts = entry.ts <= 0
              ? DateTime.now().millisecondsSinceEpoch
              : entry.ts;
          final double? percent = entry.percent?.clamp(0, 100).toDouble();

          await tx.execute(
            '''
            INSERT INTO book_progress (
              user_email,
              drive_file_id,
              cfi,
              chapter,
              percent,
              updated_at_ms,
              device_name
            ) VALUES (
              :user_email,
              :drive_file_id,
              :cfi,
              :chapter,
              :percent,
              :updated_at_ms,
              :device_name
            )
            ON DUPLICATE KEY UPDATE
              updated_at_ms = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                VALUES(updated_at_ms),
                updated_at_ms
              ),
              cfi = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                VALUES(cfi),
                cfi
              ),
              chapter = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                VALUES(chapter),
                chapter
              ),
              percent = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                VALUES(percent),
                percent
              ),
              device_name = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                VALUES(device_name),
                device_name
              ),
              updated_at = IF(
                VALUES(updated_at_ms) >= updated_at_ms,
                CURRENT_TIMESTAMP(3),
                updated_at
              )
            ''',
            <String, dynamic>{
              "user_email": normalizedUser,
              "drive_file_id": fileId,
              "cfi": entry.cfi.trim().isEmpty ? null : entry.cfi.trim(),
              "chapter": entry.chapter,
              "percent": percent,
              "updated_at_ms": ts,
              "device_name": safeDevice,
            },
          );
        }
      });
    });
  }

  Future<void> _ensureSchema(MySQLConnection conn) async {
    if (_schemaReady) {
      return;
    }

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS book_progress (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        user_email VARCHAR(320) NOT NULL,
        drive_file_id VARCHAR(191) NOT NULL,
        cfi TEXT NULL,
        chapter INT NULL,
        percent DECIMAL(6,3) NULL,
        updated_at_ms BIGINT NOT NULL,
        device_name VARCHAR(120) NOT NULL,
        updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
          ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (id),
        UNIQUE KEY uq_user_file (user_email, drive_file_id),
        KEY idx_user_updated (user_email, updated_at_ms)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');

    _schemaReady = true;
  }

  Future<T> _withConnection<T>(
    Future<T> Function(MySQLConnection conn) run,
  ) async {
    final _MySqlConnectionDetails details = _parseConnectionDetails();

    final MySQLConnection conn = await MySQLConnection.createConnection(
      host: details.host,
      port: details.port,
      userName: details.userName,
      password: details.password,
      databaseName: details.databaseName,
      secure: details.secure,
    );

    await conn.connect(timeoutMs: 12000);

    try {
      return await run(conn);
    } finally {
      await conn.close();
    }
  }

  _MySqlConnectionDetails _parseConnectionDetails() {
    final String raw = AppConfig.mysqlConnectionUri.trim();
    if (raw.isEmpty) {
      throw StateError(
        "Missing MYSQL_CONNECTION_URI. Pass it via --dart-define.",
      );
    }

    final Uri uri = Uri.parse(raw);
    if (uri.scheme.toLowerCase() != "mysql") {
      throw StateError("MYSQL_CONNECTION_URI must start with mysql://");
    }

    if (uri.host.trim().isEmpty) {
      throw StateError("MYSQL_CONNECTION_URI is missing host.");
    }

    if (uri.userInfo.trim().isEmpty || !uri.userInfo.contains(":")) {
      throw StateError("MYSQL_CONNECTION_URI must include user and password.");
    }

    final int split = uri.userInfo.indexOf(":");
    final String userName = Uri.decodeComponent(
      uri.userInfo.substring(0, split),
    );
    final String password = Uri.decodeComponent(
      uri.userInfo.substring(split + 1),
    );

    final String databaseName = uri.pathSegments.isEmpty
        ? ""
        : Uri.decodeComponent(uri.pathSegments.first);
    if (databaseName.isEmpty) {
      throw StateError("MYSQL_CONNECTION_URI is missing database name.");
    }

    final String sslMode =
        (uri.queryParameters["sslMode"] ??
                uri.queryParameters["sslmode"] ??
                uri.queryParameters["tls"] ??
                "required")
            .toLowerCase()
            .trim();

    final bool secure =
        sslMode != "disable" && sslMode != "false" && sslMode != "0";

    return _MySqlConnectionDetails(
      host: uri.host.trim(),
      port: uri.hasPort ? uri.port : 3306,
      userName: userName,
      password: password,
      databaseName: databaseName,
      secure: secure,
    );
  }

  String _normalizeUser(String email) => email.trim().toLowerCase();
}

class _MySqlConnectionDetails {
  const _MySqlConnectionDetails({
    required this.host,
    required this.port,
    required this.userName,
    required this.password,
    required this.databaseName,
    required this.secure,
  });

  final String host;
  final int port;
  final String userName;
  final String password;
  final String databaseName;
  final bool secure;
}
