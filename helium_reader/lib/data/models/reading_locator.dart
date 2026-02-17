import "dart:convert";

class ReadingLocator {
  const ReadingLocator({
    required this.href,
    this.type,
    this.title,
    this.cfi,
    this.chapter,
    this.paragraph,
    this.position,
    this.progression,
    this.totalProgression,
  });

  final String href;
  final String? type;
  final String? title;
  final String? cfi;
  final int? chapter;
  final int? paragraph;
  final int? position;
  final double? progression;
  final double? totalProgression;

  bool get hasMeaningfulPosition {
    return (position ?? -1) >= 0 ||
        (chapter ?? -1) > 0 ||
        ((cfi ?? "").trim().isNotEmpty) ||
        (progression != null && progression! >= 0);
  }

  Map<String, Object?> toJson() {
    final String normalizedHref = href.trim();
    return <String, Object?>{
      "href": normalizedHref,
      if (type?.trim().isNotEmpty ?? false) "type": type!.trim(),
      if (title?.trim().isNotEmpty ?? false) "title": title!.trim(),
      if (cfi?.trim().isNotEmpty ?? false) "cfi": cfi!.trim(),
      if (chapter != null && chapter! > 0) "chapter": chapter,
      if (paragraph != null && paragraph! > 0) "paragraph": paragraph,
      if (position != null && position! >= 0) "position": position,
      if (progression != null) "progression": progression,
      if (totalProgression != null) "totalProgression": totalProgression,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ReadingLocator.fromJson(Map<String, Object?> json) {
    final double? progression = _asDouble(json["progression"]);
    final double? totalProgression = _asDouble(json["totalProgression"]);

    return ReadingLocator(
      href: (json["href"] as String? ?? "").trim(),
      type: (json["type"] as String?)?.trim(),
      title: (json["title"] as String?)?.trim(),
      cfi: (json["cfi"] as String?)?.trim(),
      chapter: _asInt(json["chapter"]),
      paragraph: _asInt(json["paragraph"]),
      position: _asInt(json["position"]),
      progression: progression?.clamp(0, 1).toDouble(),
      totalProgression: totalProgression?.clamp(0, 1).toDouble(),
    );
  }

  static ReadingLocator? tryParse(String raw) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(input);
      if (decoded is! Map) {
        return null;
      }

      final Map<String, Object?> casted = <String, Object?>{};
      decoded.forEach((Object? key, Object? value) {
        if (key is String) {
          casted[key] = value;
        }
      });

      final ReadingLocator locator = ReadingLocator.fromJson(casted);
      if (!locator.hasMeaningfulPosition) {
        return null;
      }
      return locator;
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
