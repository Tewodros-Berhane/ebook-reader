import "dart:async";
import "dart:convert";
import "dart:io";

import "package:googleapis/drive/v3.dart" as drive;
import "package:http/http.dart" as http;

import "../../core/config/app_config.dart";
import "../models/sync_payload.dart";
import "auth_service.dart";

class DriveBook {
  const DriveBook({
    required this.fileId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.modifiedTime,
  });

  final String fileId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int modifiedTime;
}

class DriveFolder {
  const DriveFolder({required this.id, required this.name});

  final String id;
  final String name;
}

class DriveService {
  const DriveService(this._authService);

  final AuthService _authService;

  Future<List<DriveBook>> listEpubFiles({String? folderId}) {
    return _withDriveApi((api) async {
      final String scopedFolder = (folderId ?? AppConfig.scopedFolderId).trim();
      final List<String> query = <String>[
        "trashed = false",
        "mimeType != 'application/vnd.google-apps.folder'",
        "name contains '.epub'",
      ];

      if (scopedFolder.isNotEmpty) {
        query.add("'$scopedFolder' in parents");
      }

      final drive.FileList result = await api.files.list(
        q: query.join(" and "),
        spaces: "drive",
        pageSize: 200,
        orderBy: "modifiedTime desc",
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        $fields:
            "files(id,name,modifiedTime,thumbnailLink,owners(displayName))",
      );

      final List<drive.File> files = result.files ?? <drive.File>[];
      return files
          .where((file) => (file.id ?? "").isNotEmpty)
          .map((file) {
            final List<drive.User> owners = file.owners ?? <drive.User>[];
            final String author = owners.isEmpty
                ? "Unknown author"
                : (owners.first.displayName ?? "Unknown author");
            return DriveBook(
              fileId: file.id ?? "",
              title: file.name ?? "Untitled",
              author: author,
              thumbnailUrl: file.thumbnailLink ?? "",
              modifiedTime: file.modifiedTime?.millisecondsSinceEpoch ?? 0,
            );
          })
          .toList(growable: false);
    });
  }

  Future<List<DriveFolder>> listFolders({String? parentFolderId}) {
    return _withDriveApi((api) async {
      final List<String> query = <String>[
        "trashed = false",
        "mimeType = 'application/vnd.google-apps.folder'",
      ];

      final String parent = (parentFolderId ?? "").trim();
      if (parent.isNotEmpty) {
        query.add("'$parent' in parents");
      }

      final drive.FileList result = await api.files.list(
        q: query.join(" and "),
        spaces: "drive",
        orderBy: "name_natural",
        pageSize: 200,
        includeItemsFromAllDrives: true,
        supportsAllDrives: true,
        $fields: "files(id,name)",
      );

      final List<drive.File> files = result.files ?? <drive.File>[];
      return files
          .where((file) => (file.id ?? "").isNotEmpty)
          .map(
            (file) => DriveFolder(
              id: file.id!,
              name: (file.name ?? "Unnamed folder").trim(),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<void> downloadFile({
    required String fileId,
    required String localPath,
  }) {
    return _withDriveApi((api) async {
      final Object mediaObject = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
        supportsAllDrives: true,
      );

      if (mediaObject is! drive.Media) {
        throw StateError("Drive did not return media for file $fileId.");
      }

      final File file = File(localPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final IOSink sink = file.openWrite();
      await mediaObject.stream.pipe(sink);
      await sink.flush();
      await sink.close();
    });
  }

  Future<SyncFileDocument?> getSyncDocument() {
    return _withDriveApi((api) async {
      final drive.FileList list = await api.files.list(
        q: "name = 'sync.json' and trashed = false",
        spaces: "appDataFolder",
        pageSize: 1,
        $fields: "files(id,name)",
      );

      final List<drive.File> files = list.files ?? <drive.File>[];
      if (files.isEmpty || (files.first.id ?? "").isEmpty) {
        return null;
      }

      final String fileId = files.first.id!;
      final Object mediaObject = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (mediaObject is! drive.Media) {
        return null;
      }

      final String content = await utf8.decodeStream(mediaObject.stream);
      final Object decoded = jsonDecode(content);
      if (decoded is! Map) {
        return SyncFileDocument(fileId: fileId, payload: SyncPayload.empty());
      }

      final Map<String, Object?> payloadJson = <String, Object?>{};
      decoded.forEach((key, value) {
        if (key is String) {
          payloadJson[key] = value;
        }
      });

      return SyncFileDocument(
        fileId: fileId,
        payload: SyncPayload.fromJson(payloadJson),
      );
    });
  }

  Future<void> upsertSyncDocument({
    required SyncPayload payload,
    String? existingFileId,
  }) {
    return _withDriveApi((api) async {
      final List<int> bytes = utf8.encode(jsonEncode(payload.toJson()));
      final drive.Media media = drive.Media(
        Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        bytes.length,
      );

      if (existingFileId == null || existingFileId.isEmpty) {
        final drive.File metadata = drive.File()
          ..name = "sync.json"
          ..parents = <String>["appDataFolder"]
          ..mimeType = "application/json";
        await api.files.create(metadata, uploadMedia: media);
        return;
      }

      final drive.File metadata = drive.File()
        ..modifiedTime = DateTime.now().toUtc();
      await api.files.update(metadata, existingFileId, uploadMedia: media);
    });
  }

  Future<T> _withDriveApi<T>(
    Future<T> Function(drive.DriveApi api) action,
  ) async {
    Future<T> runWithToken(String token) async {
      final _BearerClient client = _BearerClient(token);
      try {
        final drive.DriveApi api = drive.DriveApi(client);
        return await action(api);
      } finally {
        client.close();
      }
    }

    final String? cachedToken = await _authService.accessToken(
      promptIfNecessary: false,
    );
    if (cachedToken != null && cachedToken.isNotEmpty) {
      try {
        return await runWithToken(cachedToken);
      } on drive.DetailedApiRequestError catch (err) {
        if (err.status != 401 && err.status != 403) {
          rethrow;
        }
      }
    }

    final String? refreshedToken = await _authService.accessToken(
      promptIfNecessary: true,
    );
    if (refreshedToken == null || refreshedToken.isEmpty) {
      throw StateError("No Google Drive access token available.");
    }

    return runWithToken(refreshedToken);
  }
}

class _BearerClient extends http.BaseClient {
  _BearerClient(this._token);

  final String _token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers["Authorization"] = "Bearer $_token";
    request.headers["Accept"] = "application/json";
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
