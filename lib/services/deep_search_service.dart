import 'package:dio/dio.dart';
import '../models/provider_config.dart';
import 'search_service.dart';
import 'ai_service.dart';

enum DeepSearchPhase { decomposing, searching, fetching, synthesizing, done }

class DeepSearchProgress {
  final DeepSearchPhase phase;
  final String message;
  final int current;
  final int total;
  const DeepSearchProgress({required this.phase, required this.message, this.current = 0, this.total = 0});
}

class DeepSearchResult {
  final String summary;
  final String detailedReport;
  final List<String> sources;
  DeepSearchResult({required this.summary, required this.detailedReport, required this.sources});
}

class DeepSearchService {
  static Stream<DeepSearchResult> search({
    required String query,
    required AIProviderConfig config,
    void Function(DeepSearchProgress)? onProgress,
    bool Function()? isCancelled,
  }) async* {
    final aiService = AiService(config);

    // Phase 1: Decompose query into sub-queries
    onProgress?.call(const DeepSearchProgress(phase: DeepSearchPhase.decomposing, message: '正在拆解问题...'));
    final subQueries = await _decomposeQuery(query, aiService);
    if (isCancelled?.call() == true) return;

    // Phase 2: Search each sub-query
    final allResults = <SearchResult>[];
    for (int i = 0; i < subQueries.length; i++) {
      if (isCancelled?.call() == true) return;
      onProgress?.call(DeepSearchProgress(
        phase: DeepSearchPhase.searching,
        message: '正在搜索: ${subQueries[i]}',
        current: i + 1,
        total: subQueries.length,
      ));
      final results = await SearchService.search(subQueries[i], maxResults: 4);
      allResults.addAll(results);
    }
    if (isCancelled?.call() == true) return;

    // Deduplicate by URL
    final seen = <String>{};
    final uniqueResults = <SearchResult>[];
    for (final r in allResults) {
      if (!seen.contains(r.url)) { seen.add(r.url); uniqueResults.add(r); }
    }
    final topResults = uniqueResults.take(10).toList();

    // Phase 3: Fetch page content
    for (int i = 0; i < topResults.length; i++) {
      if (isCancelled?.call() == true) return;
      onProgress?.call(DeepSearchProgress(
        phase: DeepSearchPhase.fetching,
        message: '正在读取: ${topResults[i].title}',
        current: i + 1,
        total: topResults.length,
      ));
      topResults[i].content = await SearchService.fetchPageContent(topResults[i].url);
    }
    if (isCancelled?.call() == true) return;

    // Phase 4: Synthesize report with AI
    onProgress?.call(const DeepSearchProgress(phase: DeepSearchPhase.synthesizing, message: 'AI 正在综合分析...'));
    final sources = topResults.map((r) => '${r.title} (${r.url})').toList();

    final contextBuffer = StringBuffer();
    for (final r in topResults) {
      contextBuffer.writeln('来源: ${r.title}');
      contextBuffer.writeln('链接: ${r.url}');
      if (r.content != null && r.content!.isNotEmpty) {
        contextBuffer.writeln('内容: ${r.content}');
      } else {
        contextBuffer.writeln('摘要: ${r.snippet}');
      }
      contextBuffer.writeln('---');
    }

    final synthesisPrompt = '请基于以下搜索结果，为用户的问题生成一份结构化的研究报告。\n\n'
        '用户问题：$query\n\n'
        '搜索结果：\n${contextBuffer}\n\n'
        '请按以下格式输出：\n'
        '## 核心观点\n（2-3句话总结）\n\n'
        '## 详细分析\n（分点展开分析）\n\n'
        '## 数据与事实\n（引用具体数据）\n\n'
        '## 结论与展望\n（总结性观点）\n\n'
        '要求：用中文回答，引用具体来源，内容详实。';

    String fullReport = '';
    await for (final chunk in aiService.streamChat(
      history: [],
      newUserMessage: synthesisPrompt,
      isCancelled: isCancelled,
    )) {
      fullReport += chunk;
      yield DeepSearchResult(
        summary: fullReport.length > 200 ? '${fullReport.substring(0, 200)}...' : fullReport,
        detailedReport: fullReport,
        sources: sources,
      );
    }

    onProgress?.call(const DeepSearchProgress(phase: DeepSearchPhase.done, message: '完成'));
  }

  static Future<List<String>> _decomposeQuery(String query, AiService aiService) async {
    final prompt = '请将以下问题拆解为3-5个具体的搜索子查询，每个子查询单独一行，不要编号，不要解释：\n\n$query';
    String result = '';
    await for (final chunk in aiService.streamChat(history: [], newUserMessage: prompt)) {
      result += chunk;
    }
    final queries = result.split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^\d+[\.\)、]\s*'), ''))
        .where((l) => l.isNotEmpty && l.length > 3)
        .toList();
    return queries.isNotEmpty ? queries : [query];
  }
}
