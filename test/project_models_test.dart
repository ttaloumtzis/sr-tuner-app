import 'package:flutter_test/flutter_test.dart';
import 'package:sr_tuner/src/project_models.dart';

void main() {
  test('parses dashboard and recoverable unavailable states', () {
    final dashboard = DashboardSummary.fromJson({
      'dataset_count': 1,
      'model_count': 1,
      'run_count': 2,
      'dataset_pair_total': 120,
      'active_model': 'starter',
      'best_psnr': 31.25,
      'backend_status': 'ok',
      'device_badge': 'CPU',
      'app_version': '0.1.0',
      'project_path': '/tmp/demo',
      'disk_warning': false,
      'busy_state': 'idle',
      'status_bar': {
        'app_version': '0.1.0',
        'project_path': '/tmp/demo',
        'vcs_available': false,
        'backend_state': 'ok',
        'disk_warning': false,
        'busy_state': 'idle',
      },
      'next_step': {
        'state': 'inference_ready',
        'title': 'Run inference',
        'description': 'A checkpoint is available.',
        'action_label': 'Open Inference',
        'target_tab': 6,
        'severity': 'success',
      },
    });

    expect(dashboard.datasetPairTotal, 120);
    expect(dashboard.bestPsnr, 31.25);
    expect(dashboard.nextStep.targetTab, 6);
  });

  test('parses dataset detail response', () {
    final detail = DatasetDetail.fromJson({
      'dataset': {
        'id': 'dataset_1',
        'name': 'pairs',
        'type': 'paired',
        'scale': 4,
        'storage_mode': 'external',
        'validation': {'usable': true, 'pair_count': 4, 'mode': 'quick'},
      },
      'sources': [
        {
          'id': 'source_1',
          'source_type': 'paired',
          'name': 'pairs',
          'pair_count': 4,
          'status': 'Ready',
          'severity': 'success',
          'actions': [
            {'id': 'inspect', 'label': 'Inspect', 'supported': true},
          ],
        },
      ],
      'health_checks': [
        {
          'id': 'pairs',
          'label': 'Matched pairs',
          'severity': 'success',
          'message': '4 matched pairs.',
        },
      ],
      'degradation_pipeline': ['Downscale: x4 bicubic'],
      'preview': {'index': 0, 'total': 4, 'lr_path': 'LR/a.png'},
      'histogram': {
        'available': false,
        'channels': [],
        'bins': [],
        'unavailable': {
          'supported': false,
          'reason': 'unavailable',
          'code': 'histogram_unavailable',
          'message': 'No histogram.',
        },
      },
      'rescan_action': {'id': 'rescan', 'label': 'Re-scan', 'supported': true},
      'export_action': {'id': 'export', 'label': 'Export', 'supported': false},
      'resynthesis': {
        'supported': false,
        'reason': 'unsupported',
        'code': 'resynthesis_unavailable',
        'message': 'Unavailable.',
      },
    });

    expect(detail.dataset.id, 'dataset_1');
    expect(detail.sources.single.actions.single.supported, isTrue);
    expect(detail.histogram.unavailable?.code, 'histogram_unavailable');
    expect(detail.resynthesis?.supported, isFalse);
  });

  test(
    'parses templates, live detail, checkpoint aggregate, and inference inspector',
    () {
      final catalog = ModelTemplateCatalog.fromJson({
        'templates': [
          {
            'id': 'internal-residual-pixelshuffle',
            'display_name': 'Internal',
            'architecture_summary': 'Residual',
            'best_for': 'Starter',
            'speed_label': 'Fast',
            'supported_scales': [2, 4],
            'vram_estimate': 'Low',
            'input_crop': 64,
            'support_state': 'supported',
            'architecture_steps': ['input', 'output'],
            'hyperparameters': {'lr': 0.0002},
            'defaults': {'scale': 4},
            'import_action': {
              'id': 'import',
              'label': 'Import',
              'supported': true,
            },
            'reset_action': {
              'id': 'reset',
              'label': 'Reset',
              'supported': true,
            },
            'save_as_model_action': {
              'id': 'save',
              'label': 'Save',
              'supported': true,
            },
          },
        ],
        'filters': {
          'support': ['supported'],
        },
      });
      expect(catalog.templates.single.supportedScales, [2, 4]);

      final live = LiveRunDetail.fromJson({
        'active': false,
        'epoch_progress': 0.5,
        'run_progress': 0.25,
        'recent_events': [],
        'log_tail': ['line'],
        'open_log': {'id': 'open_log', 'label': 'Open log', 'supported': false},
        'validation_samples': [],
      });
      expect(live.logTail.single, 'line');

      final aggregate = CheckpointAggregate.fromJson({
        'checkpoints': [],
        'actions': {
          'compare': {'id': 'compare', 'label': 'Compare', 'supported': false},
        },
      });
      expect(aggregate.actions['compare']?.supported, isFalse);

      final inspector = InferenceInspector.fromJson({
        'blocked_checklist': [
          {'id': 'checkpoint', 'label': 'Checkpoint', 'supported': false},
        ],
        'inspector': {'filename': 'out.png'},
        'recent': [],
        'add_tile_action': {
          'id': 'add_tile',
          'label': 'Add',
          'supported': false,
        },
        'batch_drop_zone': {
          'id': 'batch',
          'label': 'Batch',
          'supported': false,
        },
        'tuning': {
          'detail_boost': {
            'supported': false,
            'reason': 'unavailable',
            'code': 'tuning_unsupported',
            'message': 'Unavailable.',
          },
        },
        'compare_view': {'mode': 'slider'},
      });
      expect(inspector.tuning['detail_boost']?.code, 'tuning_unsupported');
    },
  );
}
