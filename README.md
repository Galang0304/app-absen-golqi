# Golqi Absensi — Mobile App

Aplikasi mobile untuk **karyawan** dan **leader** melakukan absensi berbasis
lokasi (GPS + geofencing) dan foto selfie, riwayat kehadiran, pengajuan
izin/cuti, slip gaji, serta (khusus leader) pengaturan jadwal tim di outletnya.

Dibangun dengan **Flutter** dan terhubung ke **Firebase** (Authentication +
Cloud Firestore) yang sama dengan dashboard admin web
([golqi-absen-web](https://github.com/Galang0304/golqi-absen-web)).

---

## Fitur Utama

- Login (email & password) — akun dibuat oleh admin lewat dashboard web
- Absen masuk dengan **selfie** + validasi **radius lokasi (geofencing)** ke outlet
- Riwayat kehadiran (hadir, terlambat, alfa, off)
- Pengajuan izin/cuti/sakit
- Slip gaji: gaji pokok, tunjangan, reward, potongan SP, total
- Profil (foto via Cloudinary, ganti nomor HP) — wajib dilengkapi sebelum bisa akses menu lain
- Khusus **role leader**: tab "Tim" untuk atur shift & hari kerja karyawan di outlet yang sama

---

## Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| Flutter SDK 3.x | `flutter --version` |
| Android Studio / Xcode | untuk emulator/device |
| Akun Firebase | project yang sama dengan dashboard web admin |
| Akun Cloudinary | untuk upload foto selfie & profil |
| Google Maps API Key | untuk peta lokasi outlet |

---

## 1. Install Dependencies

```powershell
flutter pub get
```

## 2. Konfigurasi Firebase

Gunakan FlutterFire CLI (otomatis membuat `lib/firebase_options.dart` dan
`android/app/google-services.json`):

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Pilih **project Firebase yang sama** dengan dashboard web admin, centang
platform Android (dan iOS bila perlu).

> Pastikan Firebase project sudah mengaktifkan **Authentication (Email/Password)**
> dan **Cloud Firestore**, serta rules-nya sudah di-deploy dari repo web admin.

## 3. Google Maps API Key (Android)

Buka `android/app/src/main/AndroidManifest.xml`, tambahkan di dalam tag
`<application>`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="ISI_GOOGLE_MAPS_API_KEY_ANDA" />
```

## 4. Konfigurasi Cloudinary

Buka `lib/services/cloudinary_service.dart` dan sesuaikan:

```dart
const cloudName = 'xxxxxxxxx';        // Cloud Name Anda
const uploadPreset = 'golqi_absensi'; // Upload preset unsigned
```

Buat upload preset di Cloudinary Dashboard → Settings → Upload → Add upload
preset, nama `golqi_absensi`, Signing Mode: **Unsigned**.

## 5. Jalankan Aplikasi

```powershell
flutter devices
flutter run -d <device_id>
```

Jika build Android gagal karena cache Gradle rusak:

```powershell
$env:GRADLE_USER_HOME = "C:\gradle_home"
flutter run -d <device_id>
```

## 6. Build APK Rilis

```powershell
flutter build apk --release
```

Hasil APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## Struktur Role

| Role | Akses di App |
|---|---|
| `leader` | Absen sendiri + tab **Tim** (atur shift & jadwal karyawan di outlet yang sama) |
| `karyawan` | Absen, riwayat, pengajuan izin/cuti, slip gaji |

> Akun leader & karyawan **dibuat oleh admin** dari dashboard web (menu
> Karyawan/Leader). Saat pertama login, pengguna wajib melengkapi **nomor HP**
> di halaman Profil sebelum bisa mengakses menu lain.

---

## Troubleshooting

| Masalah | Solusi |
|---|---|
| `Upload preset not found` | Pastikan nama preset persis `golqi_absensi`, mode Unsigned |
| Lokasi selalu di luar radius | Cek koordinat & radius outlet di dashboard web (menu Cabang/Outlet) |
| Build Android gagal (Gradle) | Set `GRADLE_USER_HOME` ke folder baru lalu build ulang |
| Tidak bisa login | Pastikan akun sudah dibuat admin di dashboard web & Authentication aktif |

---

## Project Terkait

- **Dashboard Admin/HRD (Web)**: https://github.com/Galang0304/golqi-absen-web

