import 'dart:convert';

import 'package:crypto/crypto.dart';

enum DeliveryStatus { uploaded, delivered }

class DeliveryRecord {
  const DeliveryRecord({
    required this.id,
    required this.fileName,
    required this.size,
    required this.sha256,
    required this.capturedAt,
    required this.mimeType,
    required this.status,
  });

  final String id;
  final String fileName;
  final int size;
  final String sha256;
  final DateTime capturedAt;
  final String mimeType;
  final DeliveryStatus status;

  factory DeliveryRecord.fromJson(Map<String, Object?> json) {
    return DeliveryRecord(
      id: json['id']! as String,
      fileName: json['file_name']! as String,
      size: json['size']! as int,
      sha256: json['sha256']! as String,
      capturedAt: DateTime.parse(json['captured_at']! as String).toUtc(),
      mimeType: json['mime_type']! as String,
      status: DeliveryStatus.values.byName(json['status']! as String),
    );
  }
}

class LocalMedia {
  const LocalMedia({
    required this.id,
    required this.fileName,
    required this.size,
    required this.capturedAt,
    required this.mimeType,
    required this.readBytes,
  });

  final String id;
  final String fileName;
  final int size;
  final DateTime capturedAt;
  final String mimeType;
  final Future<List<int>> Function() readBytes;
}

class DeletableMedia {
  const DeletableMedia({required this.local, required this.delivery});

  final LocalMedia local;
  final DeliveryRecord delivery;
}

class DeliveryMatcher {
  const DeliveryMatcher();

  Future<List<DeletableMedia>> match(
    Iterable<LocalMedia> localMedia,
    Iterable<DeliveryRecord> records,
  ) async {
    final delivered = records
        .where((record) => record.status == DeliveryStatus.delivered)
        .toList();
    final result = <DeletableMedia>[];

    for (final local in localMedia) {
      final candidates = delivered.where(
        (record) =>
            record.fileName == local.fileName &&
            record.size == local.size &&
            record.mimeType == local.mimeType &&
            record.capturedAt.toUtc() == local.capturedAt.toUtc(),
      );
      if (candidates.isEmpty) continue;

      final digest = sha256.convert(await local.readBytes()).toString();
      for (final record in candidates) {
        if (constantTimeEquals(digest, record.sha256.toLowerCase())) {
          result.add(DeletableMedia(local: local, delivery: record));
          break;
        }
      }
    }
    return result;
  }
}

bool constantTimeEquals(String left, String right) {
  final a = utf8.encode(left);
  final b = utf8.encode(right);
  if (a.isEmpty || b.isEmpty) return a.isEmpty && b.isEmpty;
  var difference = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    difference |= a[i % a.length] ^ b[i % b.length];
  }
  return difference == 0;
}
