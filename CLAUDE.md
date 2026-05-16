# PERISAI

Aplikasi parental control berbasis AI untuk mendeteksi konten judi online di HP anak. Hackathon project, dual-role app (orang tua + anak).

## Tech Stack

- **Flutter 3+** (Dart SDK >=3.0.0) — UI + state via Riverpod, navigasi via `go_router`
- **Supabase** — auth, DB (`children`, `detections`), storage (screenshot), realtime stream
- **Firebase Messaging** + `flutter_local_notifications` — notifikasi ke orang tua
- **Native Android (Kotlin)** — foreground service untuk screen capture + AI inference. Bagian native dikerjakan terpisah; Flutter side cuma konsumsi via channel.

## Arsitektur

```
┌─────────────── Flutter (Dart) ───────────────┐
│  UI screens (features/)                       │
│  ChannelService ◄──── EventChannel ─────┐    │
│       │                                   │    │
│       └────► MethodChannel ──────┐        │    │
│                                   │        │    │
└───────────────────────────────────┼────────┼────┘
                                    │        │
┌───────────────── Android (Kotlin) ▼────────┴────┐
│  MainActivity (channel bridge)                   │
│  PerisaiService (foreground, mediaProjection)    │
│    └─► capture screen → AiServerManager → ...   │
│        └─► gambling detected → SupabaseManager  │
│            + send event ke Flutter via eventSink│
│  UrlCheckerService (accessibility service)      │
└──────────────────────────────────────────────────┘
```

**Channel names:**
- Event (Android → Flutter): `com.perisai.app/detection_stream`
- Method (Flutter → Android): `com.perisai.app/service_control`

**Method calls:** `startService`, `stopService`, `sendTestEvent`.
**Event types** (dari Android): `gambling_detected`, `service_started`, `service_stopped`.

## Folder Layout (lib/)

- `core/` — theme, constants (`app_strings.dart`), config (`supabase_config.dart`), shared widgets, mock data
- `features/` — satu folder per fitur (auth, dashboard, detail, pairing, education, settings, test)
- `models/` — DTO + `fromJson` (Detection, Child, UserProfile). **Catatan:** beberapa file model bisa kosong saat awal — itu penyebab error tipe undefined; cek isinya dulu sebelum import.
- `services/` — `channel_service.dart` (bridge ke native), `supabase_service.dart`
- `router.dart` — semua route `go_router`, navigatorKey di-share dengan `ChannelService` agar service bisa push route dari background.
- `main.dart` — init Supabase, panggil `ChannelService.startListening()`, lalu jalankan `PerisaiApp`.

## Flow Aplikasi

**Splash** (`/splash`) baca SharedPreferences:
- session ada + `role == 'parent'` → `/dashboard`
- `role == 'child'` + `child_id` ada → `/scan-qr`
- selain itu → `/role-select`

**Parent:** role-select → login/register → dashboard → (add-child, detail/:id, settings)
**Child:** role-select → scan-qr → active (PopScope, gak bisa back) → (otomatis `/education` saat ada gambling_detected event)

## Native Service — Hal yang Wajib Diingat

1. **MediaProjection (Android 14+, targetSDK 35):**
   `PerisaiService.onStartCommand` HARUS panggil `startForeground()` *setelah* dapat token MediaProjection, dan pakai 3-param version dengan `ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` di API 29+. Kalau dipanggil sebelum token ada → `SecurityException` crash app.
2. **Permission flow di `MainActivity.requestAllPermissions()`** berjalan sekuensial: POST_NOTIFICATIONS → SYSTEM_ALERT_WINDOW → MediaProjection. Service baru dijalankan setelah semua granted.
3. **`startService` di Flutter** hanya menyimpan `child_id` ke `SharedPreferences` dan trigger permission chain — bukan langsung start service. Service starts setelah user accept MediaProjection dialog.
4. **`child_id` dipakai cross-layer:** Flutter simpan via Method channel arg, native baca dari `perisai_prefs` SharedPreferences (bukan flutter prefs — beda file).

## Supabase

- Config di `lib/core/config/supabase_config.dart` (hardcoded URL + anon key — ini hackathon, jangan kaget).
- Tabel: `children` (parent_id, child_name, age, ...), `detections` (child_id, screenshot_url, confidence, triggered_by, keywords, details).
- Storage bucket untuk screenshot.
- Realtime subscription dipakai di dashboard untuk auto-refresh saat detection baru masuk.

## Mock Mode

`lib/core/mock/mock_data.dart` — `MockData.useMock = true` untuk pakai data dummy. Dipakai dashboard saat dev tanpa backend live.

## Build & Run

```bash
flutter pub get
flutter run            # default debug
flutter build apk      # rilis debug APK
```

**Android settings (`android/app/build.gradle.kts`):**
- `ndkVersion = "27.0.12077973"` (plugin requirement, jangan diturunin)
- `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` — diperlukan `flutter_local_notifications`

## Konvensi Kode

- Komentar dan UI text dalam **Bahasa Indonesia** (casual, ramah).
- Pakai `withValues(alpha: x)` bukan `withOpacity(x)` (Flutter terbaru).
- Pakai `ColorScheme.surface` bukan `background` (deprecated).
- `CardThemeData` bukan `CardTheme` (di `ThemeData`).
- Selalu cek `mounted` setelah `await` sebelum pakai `BuildContext`.
- `TapGestureRecognizer` butuh `import 'package:flutter/gestures.dart'` (tidak diekspor `material.dart`).

## Testing

`test/widget_test.dart` cuma placeholder. App tidak bisa di-pump langsung di widget test karena butuh Supabase init + native channels — perlu mocking dulu kalau mau test serius.
