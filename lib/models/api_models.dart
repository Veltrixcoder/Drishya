import '../models/channel.dart';

class Subtitle {
  final String url;
  final String lang;
  Subtitle({required this.url, required this.lang});

  Map<String, String> toJson() => {'url': url, 'lang': lang};
  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    url: json['url']?.toString() ?? '',
    lang: (json['lang'] ?? json['language'] ?? 'Unknown').toString(),
  );
}

class StreamSource {
  final String quality;
  final String url;
  final String source;
  final int serverId;
  final String? referer;
  final String? origin;
  final String? size;
  final List<Subtitle>? subtitles;
  final Map<String, String>? headers;
  final int priority;

  /// When true, the player must send NO headers at all for this source.
  final bool noHeaders;

  StreamSource({
    required this.quality,
    required this.url,
    required this.source,
    required this.serverId,
    this.referer,
    this.origin,
    this.size,
    this.subtitles,
    this.headers,
    this.priority = 10,
    this.noHeaders = false,
  });

  static const String kDefaultReferer = 'https://rivestream.app/';
  static const String kDefaultOrigin = 'https://rivestream.app';

  String get resolvedReferer =>
      (referer != null && referer!.isNotEmpty) ? referer! : kDefaultReferer;
  String get resolvedOrigin =>
      (origin != null && origin!.isNotEmpty) ? origin! : kDefaultOrigin;

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      quality: json['quality']?.toString() ?? 'Auto',
      url: json['url'] ?? '',
      source: (json['server'] ?? json['provider'] ?? 'Unknown').toString(),
      serverId: json['serverId'] ?? 0,
      headers: (json['headers'] as Map?)?.cast<String, String>(),
    );
  }
  @override
  String toString() => '[$serverId] $source ($quality) - $url';
}

class IptvResponse {
  final int page;
  final int count;
  final int totalPages;
  final List<Channel> results;

  IptvResponse({
    required this.page,
    required this.count,
    required this.totalPages,
    required this.results,
  });

  factory IptvResponse.fromJson(Map<String, dynamic> json) {
    return IptvResponse(
      page: json['page'] ?? 1,
      count: json['count'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      results:
          (json['results'] as List?)
              ?.map((c) => Channel.fromJson(c))
              .toList() ??
          [],
    );
  }

  factory IptvResponse.empty() =>
      IptvResponse(page: 1, count: 0, totalPages: 1, results: []);
}

class CountryEntry {
  final String code;
  final String name;
  final String flag;
  final List<String> languages;
  const CountryEntry({
    required this.code,
    required this.name,
    required this.flag,
    required this.languages,
  });

  factory CountryEntry.fromJson(Map<String, dynamic> json) => CountryEntry(
    code: json['code']?.toString().toLowerCase() ?? '',
    name: json['name'] ?? '',
    flag: json['flag'] ?? '',
    languages: List<String>.from(json['languages'] ?? []),
  );
}

class RegionEntry {
  final String code;
  final String name;
  final List<String> countries;
  const RegionEntry({
    required this.code,
    required this.name,
    required this.countries,
  });

  factory RegionEntry.fromJson(Map<String, dynamic> json) => RegionEntry(
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    countries: List<String>.from(json['countries'] ?? []),
  );
}

class CategoryEntry {
  final String id;
  final String name;
  const CategoryEntry({required this.id, required this.name});

  factory CategoryEntry.fromJson(Map<String, dynamic> json) =>
      CategoryEntry(id: json['id'] ?? '', name: json['name'] ?? '');
}

class LanguageEntry {
  final String code;
  final String name;
  const LanguageEntry({required this.code, required this.name});

  factory LanguageEntry.fromJson(Map<String, dynamic> json) =>
      LanguageEntry(code: json['code'] ?? '', name: json['name'] ?? '');
}
