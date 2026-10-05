import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:photo_manager/photo_manager.dart';

import 'catalog.dart';
import 'delivery.dart';
import 'media_selection.dart';

void main() => runApp(const ArchiveCheckApp());

class ArchiveCheckApp extends StatelessWidget {
  const ArchiveCheckApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Arşiv Kontrol',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    home: const ArchiveCheckPage(),
  );
}

class ArchiveCheckPage extends StatefulWidget {
  const ArchiveCheckPage({super.key});

  @override
  State<ArchiveCheckPage> createState() => _ArchiveCheckPageState();
}

class _ArchiveCheckPageState extends State<ArchiveCheckPage> {
  static const _storage = FlutterSecureStorage();
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _catalog = CatalogClient();
  final _selected = <String>{};
  List<DeletableMedia> _deletable = const [];
  bool _busy = false;
  String _message = 'Bağlantı bilgilerini girip taramayı başlatın.';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _url.text = await _storage.read(key: 'catalog_url') ?? '';
    _token.text = await _storage.read(key: 'catalog_token') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) {
      setState(
        () => _message = 'Katalog adresi ve erişim anahtarı zorunludur.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = 'İzinler ve katalog kontrol ediliyor…';
    });
    try {
      await _storage.write(key: 'catalog_url', value: _url.text.trim());
      await _storage.write(key: 'catalog_token', value: _token.text.trim());
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        throw const CatalogException(
          'Fotoğraf/video erişimine izin verilmedi.',
        );
      }
      final records = await _catalog.fetchDeliveries(
        baseUrl: _url.text,
        token: _token.text,
      );
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );
      final assetsById = <String, AssetEntity>{};
      for (final path in paths) {
        final pathAssets = await path.getAssetListPaged(page: 0, size: 100000);
        for (final asset in pathAssets) {
          assetsById.putIfAbsent(asset.id, () => asset);
        }
      }
      final locals = <LocalMedia>[];
      for (final asset in assetsById.values) {
        final file = await asset.originFile;
        if (file == null) continue;
        final size = await file.length();
        locals.add(
          LocalMedia(
            id: asset.id,
            fileName: asset.title ?? file.uri.pathSegments.last,
            size: size,
            capturedAt: asset.createDateTime.toUtc(),
            mimeType: asset.mimeType ?? _mimeFromName(asset.title ?? ''),
            readBytes: file.readAsBytes,
          ),
        );
      }
      final matches = await const DeliveryMatcher().match(locals, records);
      if (!mounted) return;
      setState(() {
        _deletable = matches;
        _selected.clear();
        _message = matches.isEmpty
            ? 'Bilgisayarda doğrulanmış ve eşleşen medya bulunamadı.'
            : '${matches.length} medya bilgisayarda doğrulandı.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Hata: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = 'Sistem silme onayı bekleniyor…';
    });
    try {
      final ids = uniqueMediaIds(
        _deletable
            .where((item) => _selected.contains(item.local.id))
            .map((item) => item.local.id),
      );
      final returnedIds = await PhotoManager.editor.deleteWithIds(ids);
      final result = deletionResult(requestedIds: ids, deletedIds: returnedIds);
      if (!mounted) return;
      setState(() {
        _deletable = _deletable
            .where((item) => !result.deletedIds.contains(item.local.id))
            .toList();
        _selected.removeAll(result.deletedIds);
        _message = result.deletedCount == 0
            ? 'Silme iptal edildi veya sistem izin vermedi.'
            : '${result.deletedCount} medya sistem onayıyla silindi.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Silme başarısız: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'image/jpeg';
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Arşiv Kontrol')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Katalog adresi',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Erişim anahtarı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Doğrulanmış medyayı tara'),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message),
            ),
            if (_deletable.isNotEmpty)
              CheckboxListTile(
                key: const Key('select-all'),
                contentPadding: EdgeInsets.zero,
                value: _selected.length == _deletable.length,
                tristate: true,
                onChanged: _busy
                    ? null
                    : (checked) => setState(
                        () => updateSelectAll(
                          selected: _selected,
                          mediaIds: _deletable.map((item) => item.local.id),
                          select: checked == true,
                        ),
                      ),
                title: const Text('Tümünü seç'),
                subtitle: Text('${_selected.length} seçili'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _deletable.length,
                itemBuilder: (context, index) {
                  final item = _deletable[index];
                  return CheckboxListTile(
                    value: _selected.contains(item.local.id),
                    onChanged: _busy
                        ? null
                        : (checked) => setState(() {
                            checked == true
                                ? _selected.add(item.local.id)
                                : _selected.remove(item.local.id);
                          }),
                    title: Text(item.local.fileName),
                    subtitle: Text(
                      '${(item.local.size / 1048576).toStringAsFixed(1)} MB • SHA-256 doğrulandı',
                    ),
                  );
                },
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _selected.isEmpty || _busy ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                'Seçilenleri sistem onayıyla sil (${_selected.length})',
              ),
            ),
            if (Platform.isIOS)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'iOS silme işlemi Fotoğraflar uygulamasının onay akışını kullanır.',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
