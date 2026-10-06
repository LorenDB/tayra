import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/server_url.dart';

void main() {
  test('adds https when no scheme was typed', () {
    expect(
      normalizeServerUrl('music.example.org'),
      'https://music.example.org',
    );
    expect(
      normalizeServerUrl('  music.example.org  '),
      'https://music.example.org',
    );
  });

  test('keeps an explicit scheme, whatever its case', () {
    expect(
      normalizeServerUrl('http://localhost:5000'),
      'http://localhost:5000',
    );
    expect(
      normalizeServerUrl('HTTPS://Music.Example.org'),
      'HTTPS://Music.Example.org',
    );
  });

  test('a host that merely starts with "http" still gets a scheme', () {
    expect(
      normalizeServerUrl('httpd.example.org'),
      'https://httpd.example.org',
    );
    expect(
      normalizeServerUrl('http-music.example'),
      'https://http-music.example',
    );
  });

  test('drops trailing slashes', () {
    expect(
      normalizeServerUrl('https://music.example.org/'),
      'https://music.example.org',
    );
    expect(
      normalizeServerUrl('music.example.org///'),
      'https://music.example.org',
    );
  });

  test('leaves an empty value empty', () {
    expect(normalizeServerUrl('   '), '');
  });
}
