List<String> uniqueMediaIds(Iterable<String> ids) => ids.toSet().toList();

void updateSelectAll({
  required Set<String> selected,
  required Iterable<String> mediaIds,
  required bool select,
}) {
  selected.clear();
  if (select) selected.addAll(mediaIds);
}

DeletionResult deletionResult({
  required Iterable<String> requestedIds,
  required Iterable<String> deletedIds,
}) {
  final requested = requestedIds.toSet();
  final deleted = deletedIds.where(requested.contains).toSet();
  return DeletionResult(deletedIds: deleted);
}

class DeletionResult {
  const DeletionResult({required this.deletedIds});

  final Set<String> deletedIds;

  int get deletedCount => deletedIds.length;
}
