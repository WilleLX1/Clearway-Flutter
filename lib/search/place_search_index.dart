import 'dart:convert';

import '../models/clearway_models.dart';

class PlaceSearchEntry {
  PlaceSearchEntry({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.lat,
    required this.lon,
    required this.searchText,
  }) : normalizedPrimary = normalizeSearchText(primary);

  final GeocodeResultKind kind;
  final String primary;
  final String secondary;
  final double lat;
  final double lon;
  final String searchText;
  final String normalizedPrimary;

  GeocodeResult toResult() => GeocodeResult(
    label: secondary.isEmpty ? primary : '$primary, $secondary',
    lat: lat,
    lon: lon,
    kind: kind,
  );
}

class PlaceSearchIndex {
  const PlaceSearchIndex({
    required this.entries,
    required this.prefixes,
    required this.source,
    required this.timestamp,
  });

  factory PlaceSearchIndex.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['v'] != 1) {
      throw FormatException(
        'Unsupported place search index version ${json['v']}.',
      );
    }
    final entries = (json['e'] as List<dynamic>)
        .map((raw) {
          final values = raw as List<dynamic>;
          return PlaceSearchEntry(
            kind: values[0] == 0
                ? GeocodeResultKind.address
                : GeocodeResultKind.business,
            primary: values[1] as String,
            secondary: values[2] as String,
            lat: (values[3] as int) / 1000000,
            lon: (values[4] as int) / 1000000,
            searchText: values[5] as String,
          );
        })
        .toList(growable: false);
    final prefixes = <String, List<int>>{};
    for (final MapEntry(:key, :value)
        in (json['p'] as Map<String, dynamic>).entries) {
      prefixes[key] = (value as List<dynamic>).cast<int>();
    }
    return PlaceSearchIndex(
      entries: entries,
      prefixes: prefixes,
      source: json['source'] as String? ?? 'OpenStreetMap contributors',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  final List<PlaceSearchEntry> entries;
  final Map<String, List<int>> prefixes;
  final String source;
  final String timestamp;

  List<GeocodeResult> search(String query, {int limit = 8}) {
    final normalized = normalizeSearchText(query);
    if (normalized.length < 2) return const [];
    final words = normalized.split(' ');
    final indexWord = words.firstWhere(
      (word) => word.length >= 2 && int.tryParse(word) == null,
      orElse: () => words.first,
    );
    final prefixLength = indexWord.length < 2 ? indexWord.length : 2;
    final candidateIds =
        prefixes[indexWord.substring(0, prefixLength)] ?? const <int>[];
    final hasNumber = normalized.codeUnits.any(
      (value) => value >= 48 && value <= 57,
    );
    final matches = <({int score, PlaceSearchEntry entry})>[];
    for (final id in candidateIds) {
      final entry = entries[id];
      if (!entry.searchText.contains(normalized)) continue;
      var score = 30;
      if (entry.normalizedPrimary == normalized) {
        score = 0;
      } else if (entry.normalizedPrimary.startsWith(normalized)) {
        score = 10;
      } else if (entry.normalizedPrimary
          .split(' ')
          .any((word) => word.startsWith(normalized))) {
        score = 20;
      }
      if (hasNumber && entry.kind == GeocodeResultKind.address) score -= 4;
      matches.add((score: score, entry: entry));
    }
    matches.sort((a, b) {
      final score = a.score.compareTo(b.score);
      if (score != 0) return score;
      final length = a.entry.primary.length.compareTo(b.entry.primary.length);
      if (length != 0) return length;
      return a.entry.primary.compareTo(b.entry.primary);
    });
    return matches
        .take(limit)
        .map((match) => match.entry.toResult())
        .toList(growable: false);
  }
}

String normalizeSearchText(String value) {
  const replacements = <String, String>{
    'å': 'a',
    'ä': 'a',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ü': 'u',
    'ú': 'u',
    'í': 'i',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  var previousSpace = true;
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    final replaced = replacements[character] ?? character;
    final code = replaced.codeUnitAt(0);
    final alphaNumeric =
        (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
    if (alphaNumeric) {
      buffer.write(replaced);
      previousSpace = false;
    } else if (!previousSpace) {
      buffer.write(' ');
      previousSpace = true;
    }
  }
  return buffer.toString().trim();
}
