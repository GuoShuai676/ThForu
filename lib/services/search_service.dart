import 'dart:convert';
import 'package:dio/dio.dart';

class SearchResult {
  final String title;
  final String url;
  final String snippet;
  String? content;
  SearchResult({required this.title, required this.url, required this.snippet, this.content});
}

class SearchService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
  ));

  static Future<List<SearchResult>> search(String query, {int maxResults = 8}) async {
    try {
      final results = <SearchResult>[];
      final resp = await _dio.get(
        'https://html.duckduckgo.com/html/',
        queryParameters: {'q': query},
      );
      final html = resp.data as String;
      final linkRe = RegExp(r'<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>', dotAll: true);
      final snippetRe = RegExp(r'<a[^>]+class="result__snippet"[^>]*>(.*?)</a>', dotAll: true);
      final links = linkRe.allMatches(html).toList();
      final snippets = snippetRe.allMatches(html).toList();
      for (int i = 0; i < links.length && results.length < maxResults; i++) {
        final url = links[i].group(1) ?? '';
        final title = _stripTags(links[i].group(2) ?? '');
        final snippet = i < snippets.length ? _stripTags(snippets[i].group(1) ?? '') : '';
        if (url.isNotEmpty && title.isNotEmpty) {
          final actualUrl = _extractUrl(url);
          results.add(SearchResult(title: title, url: actualUrl, snippet: snippet));
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  static String _extractUrl(String redirectUrl) {
    final match = RegExp(r'uddg=([^&]+)').firstMatch(redirectUrl);
    if (match != null) return Uri.decodeComponent(match.group(1)!);
    return redirectUrl;
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&#x27;', "'").replaceAll('&quot;', '"').trim();
  }

  static Future<String> fetchPageContent(String url, {int maxChars = 2000}) async {
    try {
      final resp = await _dio.get(url, options: Options(responseType: ResponseType.plain));
      String text = resp.data as String;
      text = text.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
      text = text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
      text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.length > maxChars) text = text.substring(0, maxChars);
      return text;
    } catch (_) {
      return '';
    }
  }
}
