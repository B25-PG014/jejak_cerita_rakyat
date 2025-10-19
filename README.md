# 📚 Jejak Cerita Rakyat
> Aksesibel Reader Cerita Rakyat Nusantara — dibuat dengan Flutter.

**Jejak Cerita Rakyat** adalah aplikasi multiplatform (Android, Windows, Web) yang dirancang untuk melestarikan budaya Indonesia melalui digitalisasi cerita rakyat.  
Aplikasi ini menghadirkan pengalaman membaca interaktif, mendukung **Text-to-Speech (TTS)**, **font ramah disleksia**, **mode gelap**, dan **pembacaan offline**.

---

## 🚀 Fitur Utama
- 🗺️ **Peta Interaktif** — pilih cerita berdasarkan provinsi.
- 📖 **Pembaca Cerita** — teks + narasi otomatis (TTS bahasa Indonesia).
- 💾 **Offline Mode** — semua data disimpan di SQLite & assets lokal.
- ❤️ **Favorit & Lanjutkan Membaca** — simpan progres pengguna.
- ⚙️ **Aksesibilitas** — dukungan font *OpenDyslexic* & *Atkinson Hyperlegible*.
- 🌗 **Mode Gelap & Ukuran Font** — dapat disesuaikan dari menu pengaturan.

---

## 🧩 Teknologi Utama
| Komponen | Teknologi |
|-----------|------------|
| Framework | Flutter 3.9 (Dart SDK 3.9.0) |
| State Management | Provider 6.0.5 |
| Routing | go_router 14.0.0 |
| Database | sqflite 2.3.3 + path_provider |
| Aksesibilitas | flutter_tts 4.0.2, font OpenDyslexic |
| UI/UX | flutter_svg, google_fonts, carousel_slider, badges, lottie |
| Storage & Setting | shared_preferences 2.2.3 |
| CI/CD | GitHub Actions (`.github/workflows/flutter-ci.yml`) |

---

## 🧱 Struktur Proyek

lib

├── app.dart

├── main.dart

├── core/

│ ├── local/ → favorite_store.dart, reading_progress_store.dart

│ ├── utils/ → svg_anchor_loader.dart
│ └── widgets/ → story_image.dart

├── data/

│ ├── db/app_database.dart

│ ├── repositories/story_repository.dart

│ └── (dao, models, sources placeholders)

├── features/

│ ├── home/ → home_screen.dart + widgets/

│ ├── library/ → library_screen.dart, favorites_screen.dart

│ ├── reader/ → reader_screen.dart

│ ├── settings/ → setting_screen.dart

│ ├── splash/ → splash_screen.dart

│ ├── admin/ → admin_upload_page.dart, story_import_service.dart

│ └── tts_demo/ → tts_demo_screen.dart

├── providers/

│ ├── story_provider.dart

│ ├── reader_provider.dart

│ ├── settings_provider.dart

│ ├── tts_provider.dart

│ └── tts_compat_adapter.dart

└── services/

├── seed_service.dart

└── tts_service.dart


---

## ⚙️ Cara Menjalankan Proyek

### 1️⃣ Clone Repository

git clone https://github.com/<username>/jejak_cerita_rakyat.git
cd jejak_cerita_rakyat

2️⃣ Instal Dependensi
flutter pub get

3️⃣ Jalankan Aplikasi
flutter run

---

🧠 Arsitektur Sistem

Pola Provider (MVVM ringan)

[Assets/DB/JSON] 

→ StoryRepository → StoryProvider → UI (Home, Library, Reader)

ReaderProvider 

→ kontrol posisi halaman

TTSService + TTSProvider 

→ narasi suara (id-ID)

SettingsProvider → 

simpan preferensi (font, tema, ukuran)

---

🧪 Pengujian

✅ Functional: navigasi, pembacaan cerita, TTS, favorit.

✅ UI/UX: mode gelap, ukuran font, font disleksia.

✅ Data: penyimpanan progres & validasi seed/import.

✅ Performance: waktu muat < 10 detik (Android mid-range).

✅ Platform: Android.

---

⚡ CI/CD

Workflow otomatis lint + build menggunakan GitHub Actions

File: .github/workflows/flutter-ci.yml

---

📚 Tim Capstone (B25-PG014)

Fajar Andhika

Febrian Atmadhika

Fildzah Aure Gehara Zhafirah

Ulis Leuwol

---

🗺️ Rencana Pengembangan

Tambah cerita 38 provinsi Indonesia.

Fitur gamifikasi & mode anak.

Cloud sync (Firebase / Supabase).

Dukungan multi-bahasa (ID-EN).

---

<img width="1859" height="1129" alt="image" src="https://github.com/user-attachments/assets/d782f3dc-d27f-48df-b3a6-9eb24777d09a" />

📝 Lisensi

Proyek ini dikembangkan untuk tujuan edukatif dalam program Bangkit Capstone BEKUP 2025.
Lisensi dapat disesuaikan dengan kebutuhan open-source (MIT / BSD / CC-BY-SA).

🌸 “Jejak Cerita Rakyat — Membaca Indonesia, Menjaga Warisan.”
