/// Canonical resolve payload — mirrors packages/sdk-contract DeferredLink.
class DeferredLink {
  const DeferredLink({
    required this.url,
    required this.path,
    required this.linkId,
    required this.matchType,
    required this.isDeferred,
    this.params = const {},
    this.campaign,
  });

  final String url;
  final String path;
  final Map<String, String> params;
  final String linkId;
  final MatchType matchType;
  final bool isDeferred;
  final Campaign? campaign;

  factory DeferredLink.fromMap(Map<Object?, Object?> map) {
    final rawParams = map['params'];
    final params = <String, String>{};
    if (rawParams is Map) {
      rawParams.forEach((key, value) {
        if (key != null && value != null) {
          params[key.toString()] = value.toString();
        }
      });
    }

    Campaign? campaign;
    final rawCampaign = map['campaign'];
    if (rawCampaign is Map) {
      final values = <String, String>{};
      rawCampaign.forEach((key, value) {
        if (key != null && value != null) {
          values[key.toString()] = value.toString();
        }
      });
      campaign = Campaign(values);
    }

    return DeferredLink(
      url: map['url']?.toString() ?? '',
      path: map['path']?.toString() ?? '/',
      params: params,
      linkId: map['linkId']?.toString() ?? '',
      matchType: MatchType.fromWire(map['matchType']?.toString()),
      isDeferred: map['isDeferred'] == true,
      campaign: campaign,
    );
  }

  Map<String, Object?> toMap() => {
        'url': url,
        'path': path,
        'params': params,
        'linkId': linkId,
        'matchType': matchType.wireValue,
        'isDeferred': isDeferred,
        if (campaign != null) 'campaign': campaign!.values,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeferredLink &&
          url == other.url &&
          path == other.path &&
          linkId == other.linkId &&
          matchType == other.matchType &&
          isDeferred == other.isDeferred &&
          _mapEquals(params, other.params) &&
          campaign == other.campaign;

  @override
  int get hashCode => Object.hash(url, path, linkId, matchType, isDeferred);

  @override
  String toString() =>
      'DeferredLink(linkId: $linkId, path: $path, isDeferred: $isDeferred)';
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// How the deferred / warm link was matched.
enum MatchType {
  installReferrer('install_referrer'),
  clipboard('clipboard'),
  appClip('app_clip'),
  claim('claim'),
  none('none');

  const MatchType(this.wireValue);
  final String wireValue;

  static MatchType fromWire(String? value) {
    for (final type in MatchType.values) {
      if (type.wireValue == value) return type;
    }
    return MatchType.none;
  }
}

/// Optional UTM / campaign attribution.
class Campaign {
  const Campaign([this.values = const {}]);

  final Map<String, String> values;

  String? get utmSource => values['utm_source'];
  String? get utmCampaign => values['utm_campaign'];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Campaign && _mapEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values.entries);
}

/// How SdkCore should process incoming / deferred links.
enum LinkProcessingMode {
  all('all'),
  webOnly('webOnly'),
  deferredOnly('deferredOnly');

  const LinkProcessingMode(this.wireValue);
  final String wireValue;

  static LinkProcessingMode fromWire(String? value) {
    switch (value) {
      case 'webOnly':
      case 'web-only':
      case 'WEB_ONLY':
        return LinkProcessingMode.webOnly;
      case 'deferredOnly':
      case 'deferred-only':
      case 'DEFERRED_ONLY':
        return LinkProcessingMode.deferredOnly;
      default:
        return LinkProcessingMode.all;
    }
  }
}

/// Configure options for [TaqlynSdk.configure].
class SdkOptions {
  const SdkOptions({
    required this.apiBaseUrl,
    this.linkProcessingMode = LinkProcessingMode.all,
    this.env,
  });

  final String apiBaseUrl;
  final LinkProcessingMode linkProcessingMode;
  final String? env;

  Map<String, Object?> toMap() => {
        'apiBaseUrl': apiBaseUrl,
        'linkProcessingMode': linkProcessingMode.wireValue,
        if (env != null) 'env': env,
      };
}
