import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    // The logger is process-wide; leaving a test listener attached would
    // leak log events into unrelated tests.
    RwGitLogger.instance.listener = null;
  });

  group('McpLogLevel', () {
    test('wire names match the MCP specification (RFC 5424 syslog levels)', () {
      expect(McpLogLevel.values.map((l) => l.wireName), [
        'debug',
        'info',
        'notice',
        'warning',
        'error',
        'critical',
        'alert',
        'emergency',
      ]);
    });

    test(
      'enum order is severity order so index comparison filters correctly',
      () {
        expect(McpLogLevel.debug.index < McpLogLevel.warning.index, isTrue);
        expect(McpLogLevel.emergency.index > McpLogLevel.error.index, isTrue);
      },
    );

    test('fromWireName resolves valid names and rejects unknown ones', () {
      expect(McpLogLevel.fromWireName('warning'), McpLogLevel.warning);
      expect(McpLogLevel.fromWireName('verbose'), isNull);
      expect(McpLogLevel.fromWireName(null), isNull);
    });

    test('developer.log numeric levels rank in severity order', () {
      final numericLevels =
          McpLogLevel.values.map((l) => l.developerLogLevel).toList();
      for (var i = 1; i < numericLevels.length; i++) {
        expect(numericLevels[i], greaterThanOrEqualTo(numericLevels[i - 1]));
      }
    });
  });

  group('RwGitLogger', () {
    test('forwards every event to the attached listener with its severity', () {
      final received = <(McpLogLevel, String, Object?)>[];
      RwGitLogger.instance.listener =
          (level, message, error) => received.add((level, message, error));

      RwGitLogger.instance.debug('starting');
      RwGitLogger.instance.info('done');
      RwGitLogger.instance.warning('careful');
      RwGitLogger.instance.error('boom', error: const FormatException('bad'));

      expect(received, hasLength(4));
      expect(received[0].$1, McpLogLevel.debug);
      expect(received[1].$1, McpLogLevel.info);
      expect(received[2].$1, McpLogLevel.warning);
      expect(received[3].$1, McpLogLevel.error);
      expect(received[3].$2, 'boom');
      expect(received[3].$3, isA<FormatException>());
    });

    test('logging without a listener does not throw', () {
      RwGitLogger.instance.listener = null;
      expect(() => RwGitLogger.instance.info('no listener'), returnsNormally);
    });
  });
}
