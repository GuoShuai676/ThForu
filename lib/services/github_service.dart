import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RepoFile {
  final String path;
  final String content;
  final int size;
  final String language;

  RepoFile({required this.path, required this.content, required this.size, required this.language});

  Map<String, dynamic> toJson() => {'path': path, 'content': content, 'size': size, 'language': language};

  factory RepoFile.fromJson(Map<String, dynamic> j) =>
      RepoFile(path: j['path'], content: j['content'], size: j['size'], language: j['language']);
}

class CodeChunk {
  final String id;
  final String filePath;
  final String language;
  final String content;
  final String? symbolName;
  final String? symbolType;

  CodeChunk({required this.id, required this.filePath, required this.language, required this.content, this.symbolName, this.symbolType});

  Map<String, dynamic> toJson() => {
    'id': id, 'filePath': filePath, 'language': language, 'content': content,
    if (symbolName != null) 'symbolName': symbolName,
    if (symbolType != null) 'symbolType': symbolType,
  };

  factory CodeChunk.fromJson(Map<String, dynamic> j) => CodeChunk(
    id: j['id'], filePath: j['filePath'], language: j['language'], content: j['content'],
    symbolName: j['symbolName'], symbolType: j['symbolType'],
  );
}

class GitHubRepo {
  final String id;
  final String owner;
  final String repo;
  final String? token;
  String status;
  int fileCount;
  DateTime connectedAt;
  List<CodeChunk> chunks;

  GitHubRepo({
    required this.id,
    required this.owner,
    required this.repo,
    this.token,
    this.status = 'pending',
    this.fileCount = 0,
    DateTime? connectedAt,
    this.chunks = const [],
  }) : connectedAt = connectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'owner': owner, 'repo': repo, 'token': token,
    'status': status, 'fileCount': fileCount,
    'connectedAt': connectedAt.toIso8601String(),
    'chunks': chunks.map((c) => c.toJson()).toList(),
  };

  factory GitHubRepo.fromJson(Map<String, dynamic> j) => GitHubRepo(
    id: j['id'], owner: j['owner'], repo: j['repo'], token: j['token'],
    status: j['status'] ?? 'pending', fileCount: j['fileCount'] ?? 0,
    connectedAt: DateTime.tryParse(j['connectedAt'] ?? '') ?? DateTime.now(),
    chunks: (j['chunks'] as List?)?.map((c) => CodeChunk.fromJson(c)).toList() ?? [],
  );
}

class GitHubService {
  static const _prefsKey = 'github_repos';
  static const _activeKey = 'github_active_repo_id';
  static final _dio = Dio();

  static const _codeExtensions = {
    'dart', 'java', 'kt', 'py', 'js', 'ts', 'jsx', 'tsx', 'c', 'cpp', 'h', 'hpp',
    'cs', 'go', 'rs', 'swift', 'rb', 'php', 'html', 'css', 'scss', 'json', 'yaml', 'yml', 'xml', 'md', 'sql', 'sh', 'bash',
  };

  static String _detectLanguage(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'dart': 'Dart', 'java': 'Java', 'kt': 'Kotlin', 'py': 'Python',
      'js': 'JavaScript', 'ts': 'TypeScript', 'jsx': 'React JSX', 'tsx': 'React TSX',
      'c': 'C', 'cpp': 'C++', 'h': 'C/C++ Header', 'hpp': 'C++ Header',
      'cs': 'C#', 'go': 'Go', 'rs': 'Rust', 'swift': 'Swift',
      'rb': 'Ruby', 'php': 'PHP', 'html': 'HTML', 'css': 'CSS', 'scss': 'SCSS',
      'json': 'JSON', 'yaml': 'YAML', 'yml': 'YAML', 'xml': 'XML',
      'md': 'Markdown', 'sql': 'SQL', 'sh': 'Shell', 'bash': 'Shell',
    };
    return map[ext] ?? ext.toUpperCase();
  }

  static bool _isCodeFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _codeExtensions.contains(ext);
  }

  static List<CodeChunk> _chunkFile(RepoFile file) {
    final chunks = <CodeChunk>[];
    final lines = file.content.split('\n');

    if (lines.length <= 60) {
      chunks.add(CodeChunk(
        id: '${file.path}:full',
        filePath: file.path,
        language: file.language,
        content: file.content,
      ));
      return chunks;
    }

    final symbolPatterns = <RegExp>[
      RegExp(r'^(?:class|abstract\s+class|interface|enum|extension|mixin)\s+(\w+)', multiLine: true),
      RegExp(r'^(?:void|Future|Stream|int|String|bool|double|List|Map|Widget|State|dynamic)\s+(\w+)\s*\(', multiLine: true),
      RegExp(r'^(?:fun|def|function|fn)\s+(\w+)', multiLine: true),
      RegExp(r'^(?:pub|private|protected|internal)\s+(?:fun|val|var|class)\s+(\w+)', multiLine: true),
    ];

    final symbols = <_Symbol>[];
    for (final pattern in symbolPatterns) {
      for (final match in pattern.allMatches(file.content)) {
        final lineNum = file.content.substring(0, match.start).split('\n').length - 1;
        symbols.add(_Symbol(name: match.group(1) ?? 'unknown', startLine: lineNum));
      }
    }
    symbols.sort((a, b) => a.startLine.compareTo(b.startLine));

    if (symbols.isEmpty) {
      for (int i = 0; i < lines.length; i += 50) {
        final end = (i + 60).clamp(0, lines.length);
        chunks.add(CodeChunk(
          id: '${file.path}:$i',
          filePath: file.path,
          language: file.language,
          content: lines.sublist(i, end).join('\n'),
        ));
      }
      return chunks;
    }

    for (int i = 0; i < symbols.length; i++) {
      final start = symbols[i].startLine;
      final end = i + 1 < symbols.length ? symbols[i + 1].startLine : lines.length;
      final chunkLines = lines.sublist(start, end.clamp(start, lines.length));
      if (chunkLines.length > 100) {
        chunks.add(CodeChunk(
          id: '${file.path}:${symbols[i].name}',
          filePath: file.path,
          language: file.language,
          content: chunkLines.take(100).join('\n'),
          symbolName: symbols[i].name,
          symbolType: 'partial',
        ));
      } else {
        chunks.add(CodeChunk(
          id: '${file.path}:${symbols[i].name}',
          filePath: file.path,
          language: file.language,
          content: chunkLines.join('\n'),
          symbolName: symbols[i].name,
          symbolType: 'definition',
        ));
      }
    }

    if (chunks.isEmpty) {
      chunks.add(CodeChunk(
        id: '${file.path}:full',
        filePath: file.path,
        language: file.language,
        content: file.content,
      ));
    }
    return chunks;
  }

  static Future<List<GitHubRepo>> loadRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return [];
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return list.map((j) => GitHubRepo.fromJson(j)).toList();
  }

  static Future<void> saveRepos(List<GitHubRepo> repos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(repos.map((r) => r.toJson()).toList()));
  }

  static Future<GitHubRepo?> getActiveRepo() async {
    final repos = await loadRepos();
    if (repos.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeKey);
    if (activeId != null) {
      final match = repos.where((r) => r.id == activeId).toList();
      if (match.isNotEmpty && match.first.status == 'done') return match.first;
    }
    final done = repos.where((r) => r.status == 'done').toList();
    return done.isNotEmpty ? done.first : null;
  }

  static Future<void> setActiveRepo(String? repoId) async {
    final prefs = await SharedPreferences.getInstance();
    if (repoId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, repoId);
    }
  }

  static Future<GitHubRepo> connectRepo({
    required String owner,
    required String repo,
    String? token,
    void Function(String status)? onProgress,
  }) async {
    final repos = await loadRepos();
    final id = '$owner/$repo';
    final existing = repos.where((r) => r.id == id).toList();
    final repoObj = existing.isNotEmpty ? existing.first : GitHubRepo(id: id, owner: owner, repo: repo, token: token);

    repoObj.status = 'fetching';
    repoObj.fileCount = 0;
    repoObj.chunks = [];
    if (existing.isEmpty) repos.add(repoObj);
    await saveRepos(repos);
    onProgress?.call('正在连接仓库...');

    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'ThForu-App',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      onProgress?.call('正在获取文件树...');
      final treeResp = await _dio.get(
        'https://api.github.com/repos/$owner/$repo/git/trees/main?recursive=1',
        options: Options(headers: headers),
      );

      String branch = 'main';
      if (treeResp.statusCode != 200) {
        final masterResp = await _dio.get(
          'https://api.github.com/repos/$owner/$repo/git/trees/master?recursive=1',
          options: Options(headers: headers),
        );
        if (masterResp.statusCode == 200) {
          branch = 'master';
        } else {
          throw Exception('无法获取文件树 (status: ${treeResp.statusCode})');
        }
      }

      final treeData = branch == 'main' ? treeResp.data : (await _dio.get(
        'https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1',
        options: Options(headers: headers),
      )).data;

      final tree = (treeData['tree'] as List)
          .where((item) => item['type'] == 'blob' && _isCodeFile(item['path']))
          .toList();

      final maxFiles = 50;
      final filesToFetch = tree.take(maxFiles).toList();
      final allChunks = <CodeChunk>[];
      int fetched = 0;

      for (final item in filesToFetch) {
        try {
          onProgress?.call('正在下载文件 (${fetched + 1}/${filesToFetch.length})...');
          final contentResp = await _dio.get(
            'https://api.github.com/repos/$owner/$repo/contents/${item['path']}?ref=$branch',
            options: Options(headers: headers),
          );

          if (contentResp.statusCode == 200 && contentResp.data['content'] != null) {
            final content = utf8.decode(base64Decode(contentResp.data['content'].replaceAll('\n', '')));
            final file = RepoFile(
              path: item['path'],
              content: content,
              size: item['size'] ?? 0,
              language: _detectLanguage(item['path']),
            );
            allChunks.addAll(_chunkFile(file));
            fetched++;
            repoObj.fileCount = fetched;
            onProgress?.call('已下载 $fetched 个文件 (${allChunks.length} 个代码块)');
          }
        } catch (_) {}
      }

      repoObj.chunks = allChunks;
      repoObj.status = 'done';
      repoObj.fileCount = fetched;
    } catch (e) {
      repoObj.status = 'error';
    }

    await saveRepos(repos);
    return repoObj;
  }

  static Future<void> deleteRepo(String repoId) async {
    final repos = await loadRepos();
    repos.removeWhere((r) => r.id == repoId);
    await saveRepos(repos);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_activeKey) == repoId) {
      await prefs.remove(_activeKey);
    }
  }

  static List<CodeChunk> searchCode(String query, {int maxResults = 5}) {
    final keywords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (keywords.isEmpty) return [];

    final allChunks = <CodeChunk>[];
    final cachedRepos = <GitHubRepo>[];

    GitHubRepo? _activeRepoCache;

    return []; // Will be called with loaded repos
  }

  static Future<List<CodeChunk>> searchInRepos(String query, List<GitHubRepo> repos, {int maxResults = 5}) async {
    final keywords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (keywords.isEmpty) return [];

    final scored = <_ScoredChunk>[];
    for (final repo in repos) {
      if (repo.status != 'done') continue;
      for (final chunk in repo.chunks) {
        int score = 0;
        final lowerPath = chunk.filePath.toLowerCase();
        final lowerContent = chunk.content.toLowerCase();
        final lowerSymbol = (chunk.symbolName ?? '').toLowerCase();

        for (final kw in keywords) {
          if (lowerPath.contains(kw)) score += 3;
          if (lowerSymbol.contains(kw)) score += 2;
          final contentMatches = kw.allMatches(lowerContent).length;
          score += contentMatches;
        }
        if (score > 0) {
          scored.add(_ScoredChunk(chunk: chunk, score: score, repoId: repo.id));
        }
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.chunk).toList();
  }

  static String buildSystemContext(List<CodeChunk> chunks) {
    if (chunks.isEmpty) return '';
    final buffer = StringBuffer('[关联代码片段]\n');
    for (final chunk in chunks) {
      buffer.write('--- ${chunk.filePath}');
      if (chunk.symbolName != null) buffer.write(' (${chunk.symbolName})');
      buffer.write(' [${chunk.language}] ---\n');
      buffer.writeln(chunk.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

class _Symbol {
  final String name;
  final int startLine;
  _Symbol({required this.name, required this.startLine});
}

class _ScoredChunk {
  final CodeChunk chunk;
  final int score;
  final String repoId;
  _ScoredChunk({required this.chunk, required this.score, required this.repoId});
}
