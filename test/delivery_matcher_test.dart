import 'package:arsiv_kontrol/delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryMatcher', () {
    test('matches only delivered records with identical metadata and hash', () async {
      final record = DeliveryRecord(
        id: 'r1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        sha256:
            '054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8',
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        status: DeliveryStatus.delivered,
      );
      final asset = LocalMedia(
        id: 'local-1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        readBytes: () async => [0, 1, 2, 3],
      );

      final matches = await const DeliveryMatcher().match([asset], [record]);

      expect(matches, hasLength(1));
      expect(matches.single.local.id, 'local-1');
      expect(matches.single.delivery.id, 'r1');
    });

    test('matches when capture time and mime differ but hash is identical', () async {
      final record = DeliveryRecord(
        id: 'r1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        sha256:
            '054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8',
        capturedAt: DateTime.utc(2026, 1, 2, 10, 0, 0),
        mimeType: 'image/jpeg',
        status: DeliveryStatus.delivered,
      );
      final asset = LocalMedia(
        id: 'local-1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        capturedAt: DateTime.utc(2026, 1, 2, 9, 59, 58, 123),
        mimeType: 'application/octet-stream',
        readBytes: () async => [0, 1, 2, 3],
      );

      final matches = await const DeliveryMatcher().match([asset], [record]);

      expect(matches, hasLength(1));
    });

    test('does not hash a candidate whose metadata differs', () async {
      var bytesRead = false;
      final asset = LocalMedia(
        id: 'local-1',
        fileName: 'other.jpg',
        size: 4,
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        readBytes: () async {
          bytesRead = true;
          return [0, 1, 2, 3];
        },
      );
      final record = DeliveryRecord(
        id: 'r1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        sha256: 'unused',
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        status: DeliveryStatus.delivered,
      );

      final matches = await const DeliveryMatcher().match([asset], [record]);

      expect(matches, isEmpty);
      expect(bytesRead, isFalse);
    });

    test('never exposes uploaded but unverified media as deletable', () async {
      final asset = LocalMedia(
        id: 'local-1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        readBytes: () async => [0, 1, 2, 3],
      );
      final record = DeliveryRecord(
        id: 'r1',
        fileName: 'IMG_0001.jpg',
        size: 4,
        sha256:
            '054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8',
        capturedAt: DateTime.utc(2026, 1, 2),
        mimeType: 'image/jpeg',
        status: DeliveryStatus.uploaded,
      );

      expect(await const DeliveryMatcher().match([asset], [record]), isEmpty);
    });
  });
}
