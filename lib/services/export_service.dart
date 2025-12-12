import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class ExportService {
  Future<File> createExportFile(
    Map<String, dynamic> data, 
    String fileName,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    
    final jsonString = JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);
    
    return file;
  }
}