import 'package:bugman_graphs/services/census_geocoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds North Carolina to an incomplete address query', () {
    expect(
      northCarolinaGeocodeQuery('1 E Edenton St, Raleigh'),
      '1 E Edenton St, Raleigh, NC',
    );
    expect(
      northCarolinaGeocodeQuery('1 E Edenton St, Raleigh, NC 27601'),
      '1 E Edenton St, Raleigh, NC 27601',
    );
  });

  test('parses a North Carolina Census geocoder match', () {
    final point = parseNorthCarolinaCensusMatch({
      'result': {
        'addressMatches': [
          {
            'matchedAddress': '1 E EDENTON ST, RALEIGH, NC, 27601',
            'coordinates': {'x': -78.638, 'y': 35.78},
          },
        ],
      },
    });

    expect(point?.latitude, 35.78);
    expect(point?.longitude, -78.638);
  });

  test('rejects an address match outside North Carolina', () {
    expect(
      parseNorthCarolinaCensusMatch({
        'result': {
          'addressMatches': [
            {
              'matchedAddress': '1 MAIN ST, RICHMOND, VA, 23219',
              'coordinates': {'x': -77.43, 'y': 37.54},
            },
          ],
        },
      }),
      isNull,
    );
  });
}
