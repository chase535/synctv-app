import 'package:flutter/material.dart';
import 'package:synctv_app/src/generated/proto/providers/common_service.pb.dart'
    as provider_common_service;
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

bool get providerWebSessionCaptureSupported => false;

Future<List<provider_common_service.WebSessionCookie>>
captureProviderWebSession(
  BuildContext context,
  source_enum.SourceProvider provider,
) => throw UnsupportedError(
  'Provider WebSession capture is unavailable in browsers because cross-origin '
  'provider cookies cannot be read safely.',
);
