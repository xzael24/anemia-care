# Flutter & Dart Resources

## Knowledge

- [Materi dosen: Flutter Fundamentals (Arif Hidayah)](https://arifhidayah.vercel.app/flutter/index.html)
  Kurikulum utama (16 modul) yang kita ikuti berurutan. Semua modul & contoh kode diambil dari sini. Jadikan sumber pertama.
- [Dokumentasi resmi Flutter](https://docs.flutter.dev/)
  Referensi kanonik framework: widget catalog, layout, navigasi, state management. Pakai untuk cek API & best practice.
- [Dokumentasi bahasa Dart](https://dart.dev/language)
  Referensi kanonik bahasa: tipe, null safety, async/await, collection, OOP. Versi sekarang: Dart 3.13.
- [Dart: Variables](https://dart.dev/language/variables)
  Primary source Modul 3 — deklarasi variabel, `var` vs `final` vs `const`, default values, late.
- [Dart: Built-in types](https://dart.dev/language/built-in-types)
  Primary source Modul 3 — int, double, String, bool, num, records, collections.
- [Dart: Functions](https://dart.dev/language/functions)
  Primary source Modul 4 — return type, arrow, named/optional/required parameters.
- [Dart: Classes](https://dart.dev/language/classes)
  Primary source Modul 4 — constructor, getter/setter, inheritance, abstract, mixin.
- [Dart: Collections](https://dart.dev/language/collections)
  Primary source Modul 5 — List/Set/Map, spread, collection if/for, higher-order methods.
- [Dart: Asynchrony support](https://dart.dev/language/async)
  Primary source Modul 5 — Future, Stream, async/await, async*/yield.
- [Flutter: Widgets 101](https://docs.flutter.dev/ui/widgets-intro)
  Primary source Modul 6 — konsep widget tree, Stateless vs Stateful, buat UI pertama.
- [Flutter: Katalog widget](https://docs.flutter.dev/ui/widgets)
  Primary source Modul 6 — referensi visual semua widget (Text, Container, Button, Image, dll).
- [Flutter: Layout](https://docs.flutter.dev/ui/layout)
  Primary source Modul 7 — constraint flow, Row/Column, Expanded/Flexible, Stack.
- [Flutter: Building responsive UIs](https://docs.flutter.dev/ui/layout/responsive)
  Primary source Modul 7 — LayoutBuilder + MediaQuery untuk layout adaptif.
- [Flutter: Navigation](https://docs.flutter.dev/ui/navigation)
  Primary source Modul 8 — Navigator, push/pop, named routes, tab & drawer.
- [Flutter: Return data from a screen](https://docs.flutter.dev/ui/navigation/returning-data)
  Primary source Modul 8 — pola await + Navigator.pop(context, data) untuk mengambil hasil dari halaman.
- [Flutter: State management intro](https://docs.flutter.dev/data-and-backend/state-mgmt/intro)
  Primary source Modul 9 — kapan pakai setState vs lifting state up vs library state management.
- [pub.dev: provider](https://pub.dev/packages/provider)
  Primary source Modul 9 — ChangeNotifierProvider, context.watch/read/select.
- [Flutter: Networking](https://docs.flutter.dev/data-and-backend/networking)
  Primary source Modul 10 — HTTP requests, parsing JSON, FutureBuilder.
- [pub.dev: http](https://pub.dev/packages/http)
  Primary source Modul 10 — API lengkap package http (termasuk MockClient untuk test).
- [JSONPlaceholder](https://jsonplaceholder.typicode.com)
  Primary source Modul 10 — REST API publik gratis untuk latihan (dipakai direktori pasien).
- [pub.dev: sqflite](https://pub.dev/packages/sqflite)
  Primary source Modul 11 — plugin SQLite untuk Flutter (openDatabase, query/insert/update/delete).
- [pub.dev: shared_preferences](https://pub.dev/packages/shared_preferences)
  Primary source Modul 11 — key-value persisten (termasuk setMockInitialValues untuk test).
- [SQLite: SQL Language](https://www.sqlite.org/lang.html)
  Primary source Modul 11 — sintaks SQL & tipe data SQLite (mis. bool → INTEGER 0/1).
- [pub.dev: image_picker](https://pub.dev/packages/image_picker)
  Primary source Modul 12 — kamera/galeri → XFile; ImageSource, pickMultiImage.
- [pub.dev: path_provider](https://pub.dev/packages/path_provider)
  Primary source Modul 12 — direktori app: Documents vs Temporary, lintas platform.
- [pub.dev: file_picker](https://pub.dev/packages/file_picker)
  Modul 12 (teori dulu) — pilih file apa saja (PDF, gambar); calon fitur upload laporan hasil lab.
- [pub.dev: audioplayers](https://pub.dev/packages/audioplayers)
  Modul 12 (teori) — putar audio URL/asset, stream posisi/durasi.
- [Flutter: Testing](https://docs.flutter.dev/testing)
  Primary source Modul 13 — unit/widget/integration test, best practice, coverage.
- [Flutter: Testing overview](https://docs.flutter.dev/testing/overview)
  Modul 13 — piramida testing & trade-off tiap level.
- [Flutter: Integration tests](https://docs.flutter.dev/testing/integration-tests)
  Modul 13 — integration_test package SDK, jalan di device/emulator.
- [pub.dev: matcher](https://pub.dev/documentation/matcher/latest/)
  Modul 13 — API lengkap matcher untuk expect() (equals, closeTo, throws, dll).
- [package:http/testing (MockClient)](https://pub.dev/documentation/http/latest/testing/package-testing-library.html)
  Modul 13 — mock HTTP tanpa mockito/build_runner (deviasi tercatat).
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
  Primary source Modul 14 — keystore & signing, architecture APK (x86/arm), ukuran, obfuscate.
- [Android: App signing](https://developer.android.com/studio/publish/app-signing)
  Modul 14 — upload key (keystore kita) vs Play App Signing, konsekuensi kehilangan keystore.
- [Android: Android App Bundle](https://developer.android.com/guide/app-bundle)
  Modul 14 — kenapa AAB wajib buat Play Store & cara Play menurunkan APK per device.
- [pub.dev: flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)
  Modul 14 — generate ikon launcher + adaptive icon dari 1 image_path.
- [pub.dev: flutter_native_splash](https://pub.dev/packages/flutter_native_splash)
  Modul 14 — splash screen native lintas Android (termasuk Android 12+ styles v31).
- [Play Console: Publish &amp; rilis produksi](https://support.google.com/googleplay/android-developer/answer/113469)
  Primary source Modul 15 — alur rilis produksi Play Store (closed testing, staged rollout, update).
- [Android: Publish](https://developer.android.com/studio/publish)
  Modul 15 — opsi distribusi & checklist rilis Android (Play, internal, alternative stores).
- [GitHub Docs: Managing releases](https://docs.github.com/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
  Modul 15 (Skenario C) — bikin release, attach binary/asset, tag.
- [gh CLI: gh release create](https://cli.github.com/manual/gh_release_create)
  Modul 15 (Skenario C) — perintah release + upload aset dari terminal.
- [pub.dev](https://pub.dev)
  Registry package Flutter/Dart (http, sqflite, go_router, dll). Cek sebelum menulis ulang sesuatu yang sudah ada package-nya.
- [Flutter codelabs resmi](https://docs.flutter.dev/get-started/codelab)
  Latihan hands-on resmi dari Google — pelengkap materi dosen.

## Wisdom (Communities)

- [Discord Flutter](https://discord.gg/flutter) — komunitas resmi / terbesar, moderasi bagus. Buat: tanya bug/solusi.
- [r/FlutterDev (Reddit)](https://reddit.com/r/FlutterDev) — komunitas dev Flutter. Buat: baca diskusi best-practice & tren.
- [Stack Overflow `flutter`](https://stackoverflow.com/questions/tagged/flutter) — buat: error build/runtime yang sudah pernah logam orang.
- Preferensi komunitas: belum ditanyakan ke mahasiswa — update file ini kalau dia nggak mau gabung komunitas.

## Gaps

- Belum ada resource kurasi khusus untuk *health-app* (anemia) pattern — UI medical, form kesehatan, dsb. Kemungkinan perlu cari saat nanti masuk modul UI/state.