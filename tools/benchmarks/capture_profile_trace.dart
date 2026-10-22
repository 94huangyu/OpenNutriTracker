// Host-side VM timeline capture for the isolated profile installation only.
// Arguments: private URI file, output JSON, ready marker, capture seconds.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 4) throw ArgumentError('URI file, output, ready, seconds');
  final seconds = int.parse(args[3]);
  if (seconds < 1 || seconds > 60) {
    throw ArgumentError('Capture must be 1..60s');
  }
  final uri = Uri.parse((await File(args[0]).readAsString()).trim());
  if (!['127.0.0.1', 'localhost'].contains(uri.host) || uri.scheme != 'ws') {
    throw ArgumentError('Only the explicit localhost ADB forward is allowed');
  }
  final socket = await WebSocket.connect(
    uri.toString(),
  ).timeout(const Duration(seconds: 10));
  var id = 0;
  final pending = <String, Completer<dynamic>>{};
  final subscription = socket.listen((message) {
    final data = jsonDecode(message as String) as Map<String, dynamic>;
    final completer = pending.remove(data['id']?.toString());
    if (completer == null) return;
    if (data.containsKey('error')) {
      completer.completeError(StateError('${data['error']}'));
    } else {
      completer.complete(data['result']);
    }
  });
  Future<dynamic> call(String method, [Map<String, Object> params = const {}]) {
    final key = '${++id}';
    final completer = Completer<dynamic>();
    pending[key] = completer;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': key,
        'method': method,
        'params': params,
      }),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  List<String>? original;
  try {
    final flags = await call('getVMTimelineFlags') as Map<String, dynamic>;
    original = List<String>.from(flags['recordedStreams'] as List);
    await call('setVMTimelineFlags', {
      'recordedStreams': {'Dart', 'Embedder', ...original}.toList(),
    });
    await call('clearVMTimeline');
    await File(args[2]).writeAsString('ready', flush: true);
    await Future<void>.delayed(Duration(seconds: seconds));
    final timeline = await call('getVMTimeline') as Map<String, dynamic>;
    if (timeline['traceEvents'] is! List ||
        (timeline['traceEvents'] as List).isEmpty) {
      throw StateError('No timeline events; do not report a frame-rate result');
    }
    await File(args[1]).writeAsString(jsonEncode(timeline));
  } finally {
    try {
      if (original != null) {
        await call('setVMTimelineFlags', {'recordedStreams': original});
      }
    } finally {
      await subscription.cancel();
      await socket.close();
    }
  }
}
