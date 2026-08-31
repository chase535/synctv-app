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
    this.requestDesktopSiteOnMobile = false,
  });

  final source_enum.SourceProvider provider;
  final String label;
  final Uri startUri;
  final String allowedDomain;
  final bool requestDesktopSiteOnMobile;
}

ProviderWebSessionSpec providerWebSessionSpec(
  source_enum.SourceProvider provider,
) => switch (provider) {
  source_enum.SourceProvider.SOURCE_PROVIDER_IQIYI => ProviderWebSessionSpec(
    provider: provider,
    label: 'iQiyi',
    startUri: Uri.parse('https://www.iqiyi.com/'),
    allowedDomain: 'iqiyi.com',
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

String normalizeProviderCookieDomain(String domain) =>
    domain.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

bool providerWebSessionDomainAllowed(String domain, String allowedDomain) {
  final normalized = normalizeProviderCookieDomain(domain);
  final allowed = normalizeProviderCookieDomain(allowedDomain);
  return normalized == allowed || normalized.endsWith('.$allowed');
}

bool providerWebSessionUrlAllowed(Uri uri, ProviderWebSessionSpec spec) {
  return uri.scheme.toLowerCase() == 'https' &&
      uri.host.isNotEmpty &&
      providerWebSessionDomainAllowed(uri.host, spec.allowedDomain);
}
