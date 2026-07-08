import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'cloudinary_service.dart';

class AbsensiResult {
  final String status; // 'hadir' | 'terlambat'
  final double? distance;
  AbsensiResult(this.status, this.distance);
}

class LocationInfo {
  final double myLat;
  final double myLng;
  final String? outletNama;
  final double? outletLat;
  final double? outletLng;
  final double radius;
  final double? distance; // meter
  LocationInfo({
    required this.myLat,
    required this.myLng,
    this.outletNama,
    this.outletLat,
    this.outletLng,
    required this.radius,
    this.distance,
  });

  bool get withinRadius => distance != null && distance! <= radius;
}

class AttendanceService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<Map<String, dynamic>?> getUserData() async {
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data();
  }

  static Stream<Map<String, dynamic>?> userStream() {
    return _db.collection('users').doc(_uid).snapshots().map((d) => d.data());
  }

  /// Absensi hari ini (query hanya by userId, filter tanggal di client — tanpa index).
  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getTodayAbsensi() async {
    final snap = await _db.collection('absensi').where('userId', isEqualTo: _uid).get();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    for (final d in snap.docs) {
      final t = (d.data()['tanggal'] as Timestamp?)?.toDate();
      if (t != null && !t.isBefore(start) && t.isBefore(end)) return d;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getOutlet(String? nama) async {
    if (nama == null || nama.isEmpty) return null;
    final snap = await _db.collection('outlets').where('nama', isEqualTo: nama).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  /// Info lokasi untuk peta beranda: posisi sekarang, outlet, & jarak (meter).
  static Future<LocationInfo> getLocationInfo() async {
    final user = await getUserData();
    final outlet = await getOutlet(user?['cabang'] as String?);
    final position = await getCurrentPosition();
    double? distance;
    double? outletLat;
    double? outletLng;
    double radius = 100;
    if (outlet != null && outlet['latitude'] != null && outlet['longitude'] != null) {
      outletLat = (outlet['latitude'] as num).toDouble();
      outletLng = (outlet['longitude'] as num).toDouble();
      radius = (outlet['radius'] as num?)?.toDouble() ?? 100;
      distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        outletLat,
        outletLng,
      );
    }
    return LocationInfo(
      myLat: position.latitude,
      myLng: position.longitude,
      outletNama: outlet?['nama'] as String?,
      outletLat: outletLat,
      outletLng: outletLng,
      radius: radius,
      distance: distance,
    );
  }

  static Future<Map<String, dynamic>?> getShift(String? nama) async {
    if (nama == null || nama.isEmpty) return null;
    final snap = await _db.collection('shifts').where('nama', isEqualTo: nama).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  /// Ambil posisi GPS saat ini (minta izin bila perlu).
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Aktifkan GPS/Location terlebih dahulu.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Tentukan status hadir/terlambat dari shift.
  static String _determineStatus(Map<String, dynamic>? shift, DateTime now) {
    if (shift == null) return 'hadir';
    final jamMasuk = shift['jamMasuk'] as String?; // "HH:mm"
    final toleransi = (shift['toleransiTerlambat'] as num?)?.toInt() ?? 0;
    if (jamMasuk == null || !jamMasuk.contains(':')) return 'hadir';
    final parts = jamMasuk.split(':');
    final batas = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]))
        .add(Duration(minutes: toleransi));
    return now.isAfter(batas) ? 'terlambat' : 'hadir';
  }

  /// Clock in: validasi radius, tentukan status, upload selfie, simpan.
  static Future<AbsensiResult> clockIn({required File selfie}) async {
    final user = await getUserData();
    final now = DateTime.now();
    final position = await getCurrentPosition();

    // Validasi radius outlet
    final outlet = await getOutlet(user?['cabang'] as String?);
    double? distance;
    if (outlet != null && outlet['latitude'] != null && outlet['longitude'] != null) {
      distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        (outlet['latitude'] as num).toDouble(),
        (outlet['longitude'] as num).toDouble(),
      );
      final radius = (outlet['radius'] as num?)?.toDouble() ?? 100;
      if (distance > radius) {
        throw Exception(
            'Kamu di luar zona absen (${distance.round()} m dari outlet, radius ${radius.round()} m).');
      }
    }

    final shift = await getShift(user?['shift'] as String?);
    final status = _determineStatus(shift, now);

    final fotoUrl = await CloudinaryService.uploadImage(selfie);

    await _db.collection('absensi').add({
      'userId': _uid,
      'userNama': user?['nama'] ?? '',
      'userNip': user?['nip'] ?? '',
      'tanggal': Timestamp.fromDate(now),
      'shift': user?['shift'] ?? '',
      'clockIn': Timestamp.fromDate(now),
      'fotoClockIn': fotoUrl,
      'lokasiClockIn': {'latitude': position.latitude, 'longitude': position.longitude},
      'status': status,
      'keterangan': '',
      'manual': false,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return AbsensiResult(status, distance);
  }

  static Future<void> updateProfile({required String noHp}) async {
    await _db.collection('users').doc(_uid).update({
      'noHp': noHp,
      'profileComplete': true,
      'updatedAt': Timestamp.now(),
    });
  }
}
