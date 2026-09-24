import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/deployment_url.dart';

void main() {
  for (final host in [
    'my.onhomeroom.com',
    'social-vibecoding.usernodelabs.org',
  ]) {
    test('migrates API, web and version URLs from $host', () {
      for (final path in [
        '/',
        '/api/v4/mobile',
        '/api/v4/mobile/',
        '/api/v4/app-version/check',
        '/team/api/v4/mobile?mode=test#checkpoint',
      ]) {
        expect(
          canonicalHomeroomDeploymentUrl('https://$host$path'),
          'https://app.onhomeroom.com$path',
        );
      }
      expect(canonicalHomeroomDeploymentUrl('https://$host'),
          'https://app.onhomeroom.com');
      expect(canonicalHomeroomDeploymentUrl('https://$host:443/'),
          'https://app.onhomeroom.com/');
    });
  }

  test('keeps explicit version-check disable and custom deployments', () {
    for (final value in [
      '',
      'https://app.onhomeroom.com/api/v4/mobile',
      'https://staging.example.com/team/api/v4/mobile/',
      'http://localhost:3000/api/v4/mobile',
      'https://appraise-6945af.onhomeroom.com/',
    ]) {
      expect(canonicalHomeroomDeploymentUrl(value), value);
    }
  });

  test('does not treat a different origin as the production migration', () {
    for (final value in [
      'http://my.onhomeroom.com/',
      'https://my.onhomeroom.com:444/',
      'https://user@my.onhomeroom.com/',
      'https://my.onhomeroom.com.evil.example/',
      'https://my.onhomeroom.com@evil.example/',
      'https://sub.my.onhomeroom.com/',
      'https://appraise-6945af.social-vibecoding.usernodelabs.org/',
      'https://example.com/my.onhomeroom.com',
      '//my.onhomeroom.com/',
      'blob:https://my.onhomeroom.com/id',
      'https://[',
    ]) {
      expect(canonicalHomeroomDeploymentUrl(value), value);
    }
  });
}
