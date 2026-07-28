import 'dart:io';

import 'package:clearway/models/clearway_models.dart';
import 'package:clearway/search/place_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = '''
{
  "v": 1,
  "source": "OpenStreetMap contributors",
  "timestamp": "2026-07-28T00:00:00Z",
  "e": [
    [0, "Drottninggatan 12", "252 21 Helsingborg", 56046000, 12694000, "drottninggatan 12 252 21 helsingborg"],
    [1, "ICA Maxi", "Supermarket · Regementsvägen 7", 56051000, 12700000, "ica maxi supermarket regementsvagen 7 helsingborg"],
    [1, "Pålsjö Krog", "Restaurant · Helsingborg", 56070000, 12660000, "palsjo krog restaurant helsingborg"]
  ],
  "p": {
    "dr": [0],
    "he": [0, 1, 2],
    "ic": [1],
    "kr": [2],
    "ma": [1],
    "pa": [2],
    "re": [1, 2],
    "su": [1]
  }
}
''';

void main() {
  late PlaceSearchIndex index;

  setUpAll(() {
    index = PlaceSearchIndex.fromJsonString(_fixture);
  });

  test('prioritizes complete house-number address matches', () {
    final results = index.search('Drottninggatan 12');

    expect(results, hasLength(1));
    expect(results.first.kind, GeocodeResultKind.address);
    expect(results.first.label, contains('252 21 Helsingborg'));
  });

  test('finds businesses by name and category tokens', () {
    expect(index.search('ICA').first.label, startsWith('ICA Maxi'));
    expect(index.search('supermarket').first.kind, GeocodeResultKind.business);
  });

  test('autocomplete is insensitive to Swedish diacritics', () {
    final results = index.search('Palsjo');

    expect(results.first.label, startsWith('Pålsjö Krog'));
  });

  test('bundled Helsingborg index contains addresses and businesses', () async {
    final source = await File(
      'assets/search/helsingborg.places.json',
    ).readAsString();
    final bundled = PlaceSearchIndex.fromJsonString(source);
    final addressCount = bundled.entries
        .where((entry) => entry.kind == GeocodeResultKind.address)
        .length;
    final businessCount = bundled.entries
        .where((entry) => entry.kind == GeocodeResultKind.business)
        .length;

    expect(addressCount, greaterThan(30000));
    expect(businessCount, greaterThan(1500));
    expect(bundled.search('Drottninggatan 1'), isNotEmpty);
    expect(bundled.search('ICA Nara').first.kind, GeocodeResultKind.business);
  });
}
