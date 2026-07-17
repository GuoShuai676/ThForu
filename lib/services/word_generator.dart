import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

class WordGenerator {
  static Future<File> generate({
    required String title,
    required List<Map<String, String>> messages,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();

    // Document XML
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    buffer.writeln('<w:body>');

    // Title
    buffer.writeln('<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="36"/><w:szCs w:val="36"/></w:rPr>'
        '<w:t>${_esc(title)}</w:t></w:r></w:p>');

    // Messages
    for (final msg in messages) {
      final role = msg['role'] == 'user' ? '用户' : 'AI';
      final content = msg['content'] ?? '';

      buffer.writeln(
          '<w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="2196F3"/></w:rPr>'
          '<w:t>[$role]</w:t></w:r></w:p>');

      for (final line in content.split('\n')) {
        buffer.writeln('<w:p><w:r><w:rPr><w:sz w:val="22"/></w:rPr>'
            '<w:t xml:space="preserve">${_esc(line)}</w:t></w:r></w:p>');
      }
      buffer.writeln('<w:p><w:r><w:br/></w:r></w:p>');
    }

    buffer.writeln('</w:body></w:document>');

    final docBytes = utf8.encode(buffer.toString());

    // Content types
    final ctBytes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>');

    // Root rels
    final rootRelsBytes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>');

    // Word rels
    final wordRelsBytes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '</Relationships>');

    // Build ZIP
    final archive = Archive();
    archive
        .addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));
    archive
        .addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));
    archive.addFile(ArchiveFile(
        'word/_rels/document.xml.rels', wordRelsBytes.length, wordRelsBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('Failed to encode DOCX');

    final file = File(outputPath);
    await file.writeAsBytes(zipBytes);
    return file;
  }

  static String _esc(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
