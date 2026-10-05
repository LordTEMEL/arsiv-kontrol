import 'package:arsiv_kontrol/media_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates scanned media ids while preserving order', () {
    final unique = uniqueMediaIds(['1', '2', '1', '3', '2']);

    expect(unique, ['1', '2', '3']);
  });

  test('select all keeps exactly 45 unique media ids', () {
    final selected = <String>{'old'};
    final ids = [for (var index = 0; index < 45; index++) '$index', '1'];

    updateSelectAll(selected: selected, mediaIds: ids, select: true);

    expect(selected, hasLength(45));
    expect(selected, isNot(contains('old')));

    updateSelectAll(selected: selected, mediaIds: ids, select: false);
    expect(selected, isEmpty);
  });

  test('counts each deleted media id once', () {
    final result = deletionResult(
      requestedIds: ['1', '2', '3'],
      deletedIds: ['1', '1', '2', '2'],
    );

    expect(result.deletedIds, {'1', '2'});
    expect(result.deletedCount, 2);
  });

  test('ignores deleted ids that were not requested', () {
    final result = deletionResult(
      requestedIds: ['1', '2'],
      deletedIds: ['1', 'unexpected'],
    );

    expect(result.deletedIds, {'1'});
    expect(result.deletedCount, 1);
  });
}
