# Arşiv Kontrol

Android/iOS telefon medyasını, bilgisayardaki arşiv kopyası **boyut ve SHA-256 ile doğrulandıktan sonra** silinebilir gösterir. Uygulama hiçbir dosyayı sessizce silmez; seçim kullanıcıya aittir ve silme platformun sistem onay akışından geçer.

## Bileşenler

- Flutter mobil uygulaması: yerel fotoğraf/video metadatasını katalogla ön eşleştirir, yalnız adayların SHA-256 değerini hesaplar.
- `backend/catalog.py scan`: medyayı arşive kopyalar, `fsync`, boyut ve SHA-256 doğrulaması yapar; kaynak dosyayı silmez.
- `backend/catalog.py serve`: yalnız `delivered` kayıtlarını bearer token ile sunar.

## Bilgisayarda kullanım

```bash
export ARCHIVE_CATALOG_TOKEN="uzun-rastgele-en-az-24-karakter"
python3 backend/catalog.py --db /guvenli/yol/catalog.sqlite3 scan /telefon-medya /arsiv
python3 backend/catalog.py --db /guvenli/yol/catalog.sqlite3 serve --host 127.0.0.1 --port 8787
```

Telefonun erişebilmesi için API’yi doğrudan internete açmak yerine WireGuard/Tailscale gibi özel VPN üzerinden yayınlayın. Sunucunun VPN adresine bağlanmak için `--host` değerini VPN arayüzünün IP’si yapın. Mobil uygulamada katalog adresi olarak örneğin `http://10.66.66.1:8787` ve aynı token girilir. Genel internet kullanılıyorsa TLS sonlandırması zorunludur.

## Geliştirme

```bash
flutter pub get
flutter test
flutter analyze
flutter build apk --release
python3 -m unittest discover -s backend -p 'test_*.py'
```

Linux üzerinde iOS imzalı paket üretilemez. iOS kaynakları repodadır; imzalama macOS/Xcode ve kullanıcıya ait Apple sertifikalarıyla yapılır.

## Güvenlik sınırları

- `uploaded` kayıtlar asla silinebilir değildir.
- Katalog eşleşmesi dosya adı, boyut, MIME türü, çekim zamanı ve SHA-256 gerektirir.
- Tarayıcı kaynak medyayı silmez.
- Token mobil güvenli depoda tutulur; token, veritabanı, imzalama anahtarı ve `.env` repoya eklenmez.
