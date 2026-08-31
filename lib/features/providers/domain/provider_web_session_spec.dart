import 'package:flutter/foundation.dart';
import 'package:synctv_app/src/generated/proto/source_config.pbenum.dart'
    as source_enum;

@immutable
class ProviderWebSessionSpec {
  const ProviderWebSessionSpec({
    required this.provider,
    required this.label,
    required this.startUri,
    required this.allowedDomain,
    this.additionalAllowedDomains = const <String>[],
    this.cookieLookupUris = const <Uri>[],
    this.requestDesktopSiteOnMobile = false,
  });

  final source_enum.SourceProvider provider;
  final String label;
  final Uri startUri;
  final String allowedDomain;
  final List<String> additionalAllowedDomains;
  final List<Uri> cookieLookupUris;
  final bool requestDesktopSiteOnMobile;

  List<String> get allowedDomains => <String>[
    allowedDomain,
    ...additionalAllowedDomains,
  ];

  List<Uri> get effectiveCookieLookupUris =>
      cookieLookupUris.isEmpty ? <Uri>[startUri] : cookieLookupUris;
}

ProviderWebSessionSpec providerWebSessionSpec(
  source_enum.SourceProvider provider,
) => switch (provider) {
  source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI => ProviderWebSessionSpec(
    provider: provider,
    label: 'iQiyi',
    startUri: Uri.parse('https://www.iqiyi.com/'),
    allowedDomain: 'iqiyi.com',
    additionalAllowedDomains: const <String>['qiyi.com'],
    cookieLookupUris: <Uri>[
      Uri.parse('https://www.iqiyi.com/'),
      Uri.parse('https://www.qiyi.com/'),
    ],
    requestDesktopSiteOnMobile: true,
  ),
  source_enum.SourceProvider.SOURCE_PROVIDER_TENCENT_VIDEO =>
    ProviderWebSessionSpec(
      provider: provider,
      label: 'Tencent Video',
      startUri: Uri.parse('https://v.qq.com/'),
      allowedDomain: 'qq.com',
    ),
  _ => throw ArgumentError.value(
    provider,
    'provider',
    'WebSession only supports iQiyi and Tencent Video',
  ),
};

String normalizeProviderCookieDomain(String domain) {
  final trimmed = domain.trim();
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.host.isNotEmpty) {
    return parsed.host.toLowerCase();
  }
  return trimmed.toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
}

bool providerWebSessionDomainAllowed(String domain, String allowedDomain) {
  final normalized = normalizeProviderCookieDomain(domain);
  final allowed = normalizeProviderCookieDomain(allowedDomain);
  return normalized == allowed || normalized.endsWith('.$allowed');
}

bool providerWebSessionDomainAllowedForSpec(
  String domain,
  ProviderWebSessionSpec spec,
) {
  return spec.allowedDomains.any(
    (allowedDomain) =>
        providerWebSessionDomainAllowed(domain, allowedDomain),
  );
}

bool providerWebSessionUrlAllowed(Uri uri, ProviderWebSessionSpec spec) {
  return uri.scheme.toLowerCase() == 'https' &&
      uri.host.isNotEmpty &&
      providerWebSessionDomainAllowedForSpec(uri.host, spec);
}
