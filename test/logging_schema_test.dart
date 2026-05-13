import 'package:flutter_test/flutter_test.dart';

import 'package:sr_tuner/src/cause_codes.dart';
import 'package:sr_tuner/src/logging_schema.dart';

void main() {
  group('LogLevel', () {
    test('default minimum is info', () {
      expect(LogLevel.minimum, LogLevel.info);
    });

    test('isEnabled gates correctly', () {
      expect(LogLevel.error.isEnabled(), true);
      expect(LogLevel.info.isEnabled(), true);
      expect(LogLevel.debug.isEnabled(), false);
      expect(LogLevel.trace.isEnabled(), false);
    });
  });

  group('EventNames', () {
    test('event names are stable', () {
      expect(EventNames.backendStart, 'sr.backend.start');
      expect(EventNames.requestIngress, 'sr.request.ingress');
      expect(EventNames.jobQueued, 'sr.job.queued');
      expect(EventNames.jobCompleted, 'sr.job.completed');
      expect(EventNames.jobFailed, 'sr.job.failed');
      expect(EventNames.metricsIngest, 'sr.metrics.ingest');
      expect(EventNames.telemetryUnavailable, 'sr.telemetry.unavailable');
      expect(EventNames.inferenceSubmit, 'sr.inference.submit');
      expect(EventNames.inferenceBatchSummary, 'sr.inference.batch_summary');
    });
  });

  group('LogEvent required fields', () {
    test('toMap contains all required fields', () {
      final event = LogEvent(
        level: LogLevel.info,
        component: 'test',
        event: EventNames.backendStart,
        message: 'test message',
        sessionId: 'sess-1',
        requestId: 'req-1',
        correlationId: 'corr-1',
        context: {'key': 'value'},
      );
      final map = event.toMap(redact: false);
      expect(map['timestamp'], isNotEmpty);
      expect(map['level'], 'info');
      expect(map['component'], 'test');
      expect(map['event'], EventNames.backendStart);
      expect(map['message'], 'test message');
      expect(map['session_id'], 'sess-1');
      expect(map['request_id'], 'req-1');
      expect(map['correlation_id'], 'corr-1');
      expect(map['context'], {'key': 'value'});
    });
  });

  group('Redaction', () {
    test('shouldRedact matches sensitive keys', () {
      expect(shouldRedact('token'), true);
      expect(shouldRedact('session_token'), true);
      expect(shouldRedact('x-sr-tuner-token'), true);
      expect(shouldRedact('authorization'), true);
      expect(shouldRedact('secret_key'), true);
      expect(shouldRedact('password'), true);
      expect(shouldRedact('name'), false);
      expect(shouldRedact('path'), false);
    });

    test('redaction is applied to sensitive fields', () {
      final event = LogEvent(
        component: 'test',
        event: 'sr.test.event',
        message: 'test',
        context: {'token': 'secret-value', 'name': 'visible'},
      );
      final map = event.toMap(redact: true);
      expect(map['context']!['token'], redactedPlaceholder);
      expect(map['context']!['name'], 'visible');
    });

    test('redaction preserves non-sensitive nested values', () {
      final event = LogEvent(
        component: 'test',
        event: 'sr.test.event',
        message: 'test',
        context: {
          'nested': {'secret': 'should-redact', 'visible': 'ok'},
        },
      );
      final map = event.toMap(redact: true);
      final nested = map['context']!['nested'] as Map<String, dynamic>;
      expect(nested['secret'], redactedPlaceholder);
      expect(nested['visible'], 'ok');
    });
  });

  group('CauseCodes', () {
    test('cause codes are stable', () {
      expect(CauseCodes.startupHealthTimeout, 'startup_health_timeout');
      expect(CauseCodes.transportTimeout, 'transport_timeout');
      expect(CauseCodes.pollTimeout, 'poll_timeout');
      expect(CauseCodes.telemetryCudaUnavailable, 'telemetry_cuda_unavailable');
      expect(CauseCodes.redactionSensitiveKey, 'redaction_sensitive_key');
      expect(CauseCodes.correlationFallbackGenerated, 'correlation_fallback_generated');
    });
  });
}
