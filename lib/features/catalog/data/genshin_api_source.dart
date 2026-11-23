import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../domain/catalog.dart';
import 'genshin_api_catalog.dart';

class CatalogDownloadException implements Exception {
  const CatalogDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpstreamRevision {
  const UpstreamRevision(this.sha, this.committedAt);
  final String sha;
  final DateTime committedAt;
}

/// Downloads genshin-api's data straight from GitHub. The app reads the
/// stored copy afterwards, so it only needs internet while updating.
class GenshinApiSource {
  GenshinApiSource({HttpClient Function()? client, this.branch = 'main'})
    : _client = client ?? HttpClient.new;
  final HttpClient Function() _client;
  final String branch;
  static const _maxDownloadBytes = 50 * 1024 * 1024;

  Future<List<int>> _get(Uri uri, {String? accept}) async {
    final client = _client()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'GI-Calculator');
      if (accept != null) request.headers.set(HttpHeaders.acceptHeader, accept);
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const CatalogDownloadException(
          'GitHub limitó las consultas por un rato. Inténtalo de nuevo en unos minutos.',
        );
      }
      if (response.statusCode != 200) {
        throw CatalogDownloadException(
          'GitHub respondió con el código ${response.statusCode}.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        bytes.addAll(chunk);
        if (bytes.length > _maxDownloadBytes) {
          throw const CatalogDownloadException(
            'La descarga es más grande de lo esperado.',
          );
        }
      }
      return bytes;
    } on SocketException {
      throw const CatalogDownloadException(
        'Sin conexión a internet. Tu catálogo actual se conserva.',
      );
    } on HandshakeException {
      throw const CatalogDownloadException(
        'No se pudo establecer una conexión segura con GitHub.',
      );
    } on HttpException {
      throw const CatalogDownloadException('La conexión con GitHub se cortó.');
    } finally {
      client.close(force: true);
    }
  }

  Future<UpstreamRevision> latestRevision() async {
    final body = await _get(
      Uri.https(
        'api.github.com',
        '/repos/$genshinApiRepository/commits/$branch',
      ),
      accept: 'application/vnd.github+json',
    );
    try {
      final json = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      final commit = json['commit'] as Map<String, dynamic>;
      final committer = commit['committer'] as Map<String, dynamic>;
      return UpstreamRevision(
        json['sha'] as String,
        DateTime.parse(committer['date'] as String),
      );
    } catch (_) {
      throw const CatalogDownloadException(
        'GitHub devolvió una respuesta inesperada.',
      );
    }
  }

  Future<CatalogBundle> download(
    UpstreamRevision revision, {
    Map<String, String> spanishNames = const {},
    Map<String, String> genders = const {},
  }) async {
    final bytes = await _get(
      Uri.https(
        'codeload.github.com',
        '/$genshinApiRepository/zip/${revision.sha}',
      ),
    );
    return catalogFromArchive(
      bytes,
      revision,
      spanishNames: spanishNames,
      genders: genders,
    );
  }
}

/// Reads the `data/` folder of a GitHub zip archive and converts it.
CatalogBundle catalogFromArchive(
  List<int> bytes,
  UpstreamRevision revision, {
  Map<String, String> spanishNames = const {},
  Map<String, String> genders = const {},
}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const CatalogDownloadException('El archivo descargado está dañado.');
  }
  final files = <String, Object?>{};
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final parts = file.name.split('/');
    // GitHub wraps everything in a "<repo>-<sha>/" folder.
    if (parts.length < 3 || parts[1] != 'data' || !file.name.endsWith('.json')) {
      continue;
    }
    files[parts.sublist(2).join('/')] = jsonDecode(
      utf8.decode(file.content as List<int>),
    );
  }
  return buildGenshinApiCatalog(
    files: files,
    revision: revision.sha,
    committedAt: revision.committedAt,
    spanishNames: spanishNames,
    genders: genders,
  );
}
