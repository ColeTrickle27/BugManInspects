import 'package:bugman_graphs/services/portal_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mounted Graphs keeps the current Preview or Production environment',
      () {
    for (final origin in [
      'https://feature-example.holloman-ops-brain.pages.dev',
      'https://ops.holloman-ext.com',
    ]) {
      expect(opsBrainHomeUrl(Uri.parse('$origin/bugman-graphs/#/new-job')),
          '$origin/');
    }
  });

  test('standalone Graphs returns to OpsBrain home without graph parameters',
      () {
    expect(
      opsBrainHomeUrl(
          Uri.parse('https://graphs.holloman-ext.com/?graph=example#/new-job')),
      'https://ops.holloman-ext.com/',
    );
  });
}
