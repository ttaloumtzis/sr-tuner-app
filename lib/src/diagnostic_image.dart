import 'package:flutter/material.dart';

import 'diagnostic_logger.dart';
import 'logging_schema.dart';

class DiagnosticNetworkImage extends StatefulWidget {
  const DiagnosticNetworkImage({
    super.key,
    required this.uri,
    required this.assetKind,
    this.fit,
    this.cacheKey,
    this.label,
  });

  final Uri uri;
  final String assetKind;
  final BoxFit? fit;
  final String? cacheKey;
  final String? label;

  @override
  State<DiagnosticNetworkImage> createState() => _DiagnosticNetworkImageState();
}

class _DiagnosticNetworkImageState extends State<DiagnosticNetworkImage> {
  final _log = createComponentLogger(Components.frontend);

  @override
  void initState() {
    super.initState();
    _log.info(
      EventNames.assetLoadStart,
      'Loading preview asset: ${widget.assetKind}',
      context: {
        'asset_kind': widget.assetKind,
        'url': widget.uri.path,
        'cache_key': widget.cacheKey,
        'label': widget.label,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.uri.toString(),
            key: ValueKey('${widget.assetKind}:${widget.cacheKey ?? ''}'),
            fit: widget.fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null && !wasSynchronouslyLoaded) {
                _log.info(
                  EventNames.assetLoadComplete,
                  'Preview asset loaded: ${widget.assetKind}',
                  context: {
                    'asset_kind': widget.assetKind,
                    'url': widget.uri.path,
                  },
                );
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _log.error(
                EventNames.assetLoadFailed,
                'Preview asset load failed: ${widget.assetKind}',
                context: {
                  'asset_kind': widget.assetKind,
                  'url': widget.uri.path,
                  'error': error.toString(),
                },
              );
              return Container(
                color: Colors.black26,
                child: Center(
                  child: Text(
                    widget.label ?? 'Load failed',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              );
            },
          ),
          if (widget.label != null)
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(widget.label!, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
