import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';

void main() async {
  print('Starting debug script...');
  final registry = McpRegistry();
  final inputStreamController = StreamController<List<int>>.broadcast();
  final outputStreamController = StreamController<List<int>>.broadcast();
  final errorStreamController = StreamController<List<int>>.broadcast();
  final outputSink = IOSink(outputStreamController.sink);
  final errorSink = IOSink(errorStreamController.sink);

  final server = McpServer(
    registry: registry,
    inputStream: inputStreamController.stream,
    outputSink: outputSink,
    errorSink: errorSink,
  );

  server.start();

  inputStreamController.add(utf8.encode('${jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
      })}\n'));

  final outputLines = await outputStreamController.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .take(1)
      .toList();

  print('Result: $outputLines');

  print('Closing...');
  await inputStreamController.close();
  await outputSink.close();
  await errorSink.close();
  print('Done.');
}
