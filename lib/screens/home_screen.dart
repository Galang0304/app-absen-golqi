import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/attendance_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  QueryDocumentSnapshot<Map<String, dynamic>>? _today;
  bool _loadingToday = true;
  bool _processing = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  LocationInfo? _loc;
  bool _loadingMap = true;
  String? _mapError;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadToday();
    _loadMap();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() => _loadingToday = true);
    final doc = await AttendanceService.getTodayAbsensi();
    if (!mounted) return;
    setState(() {
      _today = doc;
      _loadingToday = false;
    });
  }

  Future<void> _loadMap() async {
    setState(() {
      _loadingMap = true;
      _mapError = null;
    });
    try {
      final info = await AttendanceService.getLocationInfo();
      if (!mounted) return;
      setState(() {
        _loc = info;
        _loadingMap = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToLocations());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mapError = _cleanError(e);
        _loadingMap = false;
      });
    }
  }

  Future<File?> _takeSelfie() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 800,
    );
    return img == null ? null : File(img.path);
  }

  Future<void> _doClockIn() async {
    final selfie = await _takeSelfie();
    if (selfie == null) return;
    setState(() => _processing = true);
    try {
      final result = await AttendanceService.clockIn(selfie: selfie);
      await _loadToday();
      await _loadMap();
      if (!mounted) return;
      _snack(
        result.status == 'terlambat'
            ? 'Absen masuk tercatat — Terlambat.'
            : 'Absen masuk berhasil — Hadir.',
        ok: result.status != 'terlambat',
      );
    } catch (e) {
      if (mounted) _snack(_cleanError(e), ok: false);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: AttendanceService.userStream(),
          builder: (context, snap) {
            final user = snap.data;
            final nama = (user?['nama'] as String?) ?? 'Karyawan';
            final profileComplete = (user?['profileComplete'] as bool?) ?? false;
            final noHp = (user?['noHp'] as String?) ?? '';

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await _loadToday();
                await _loadMap();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _header(nama, user?['cabang'] as String?),
                  const SizedBox(height: 20),
                  if (!profileComplete || noHp.isEmpty) _profilePrompt(),
                  _clockCard(),
                  const SizedBox(height: 16),
                  _statusCard(),
                  const SizedBox(height: 20),
                  _mapCard(),
                  const SizedBox(height: 20),
                  _actionButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(String nama, String? cabang) {
    final now = DateTime.now();
    final tgl = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Halo, $nama 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 4),
        Text(tgl, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        if (cabang != null && cabang.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.store_mall_directory_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(cabang, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  Widget _profilePrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Lengkapi nomor HP kamu di menu Profil.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
        ),
      ]),
    );
  }

  Widget _clockCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Waktu Sekarang',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('HH:mm:ss').format(_now),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    if (_loadingToday) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    final data = _today?.data();
    final clockIn = (data?['clockIn'] as Timestamp?)?.toDate();
    final status = data?['status'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Absensi Hari Ini',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (data == null)
              const Column(children: [
                Icon(Icons.access_time_rounded, size: 44, color: AppColors.border),
                SizedBox(height: 8),
                Text('Belum absen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text('Silakan absen masuk', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ])
            else ...[
              _statusBadge(status),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _timeBox('Jam Masuk', clockIn, Icons.login_rounded, AppColors.success),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    Color c;
    String label;
    switch (status) {
      case 'terlambat':
        c = AppColors.warning;
        label = 'Terlambat';
        break;
      case 'tidak_hadir':
        c = AppColors.danger;
        label = 'Tidak Hadir';
        break;
      default:
        c = AppColors.success;
        label = 'Hadir';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _timeBox(String label, DateTime? time, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(time != null ? DateFormat('HH:mm').format(time) : '--:--',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]);
  }

  Widget _mapCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('Lokasi Kamu Sekarang',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
          const Spacer(),
          IconButton(
            onPressed: _loadingMap ? null : _loadMap,
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textMuted),
            tooltip: 'Perbarui lokasi',
            visualDensity: VisualDensity.compact,
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: _mapContent(),
          ),
        ),
        if (_loc != null && !_loadingMap) _distanceBanner(_loc!),
        if (_loc?.outletLat != null && _loc?.outletLng != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _focusOnOutlet,
              icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
              label: Text('Lihat Lokasi ${_loc?.outletNama ?? 'Toko'}'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _focusOnOutlet() async {
    final loc = _loc;
    final controller = _mapController;
    if (loc?.outletLat == null || loc?.outletLng == null || controller == null) return;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(loc!.outletLat!, loc.outletLng!), zoom: 17),
    ));
  }

  Future<void> _fitMapToLocations() async {
    final loc = _loc;
    final controller = _mapController;
    if (loc?.outletLat == null || loc?.outletLng == null || controller == null) return;

    final me = LatLng(loc!.myLat, loc.myLng);
    final toko = LatLng(loc.outletLat!, loc.outletLng!);
    if (loc.withinRadius) {
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: me, zoom: 16),
      ));
      return;
    }
    final southwest = LatLng(
      me.latitude < toko.latitude ? me.latitude : toko.latitude,
      me.longitude < toko.longitude ? me.longitude : toko.longitude,
    );
    final northeast = LatLng(
      me.latitude > toko.latitude ? me.latitude : toko.latitude,
      me.longitude > toko.longitude ? me.longitude : toko.longitude,
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: southwest, northeast: northeast),
      70,
    ));
  }

  Widget _mapContent() {
    if (_loadingMap) {
      return Container(
        color: AppColors.primaryLight,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_mapError != null) {
      return Container(
        color: AppColors.primaryLight,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_off_rounded, color: AppColors.danger, size: 32),
            const SizedBox(height: 8),
            Text(_mapError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.text)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadMap, child: const Text('Coba lagi')),
          ]),
        ),
      );
    }
    final loc = _loc;
    if (loc == null) return const SizedBox();

    final me = LatLng(loc.myLat, loc.myLng);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('me'),
        position: me,
        infoWindow: const InfoWindow(title: 'Posisi Kamu'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    final circles = <Circle>{};
    final polylines = <Polyline>{};
    LatLng center = me;

    if (loc.outletLat != null && loc.outletLng != null) {
      final toko = LatLng(loc.outletLat!, loc.outletLng!);
      markers.add(Marker(
        markerId: const MarkerId('toko'),
        position: toko,
        infoWindow: InfoWindow(title: loc.outletNama ?? 'Toko'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
      ));
      circles.add(Circle(
        circleId: const CircleId('radius'),
        center: toko,
        radius: loc.radius,
        fillColor: AppColors.primary.withValues(alpha: 0.12),
        strokeColor: AppColors.primary,
        strokeWidth: 1,
      ));
      if (!loc.withinRadius) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route-to-outlet'),
          points: [me, toko],
          color: AppColors.primary,
          width: 5,
          patterns: [PatternItem.dash(18), PatternItem.gap(10)],
        ));
      }
      center = LatLng((loc.myLat + loc.outletLat!) / 2, (loc.myLng + loc.outletLng!) / 2);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 16),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToLocations();
      },
      markers: markers,
      circles: circles,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _distanceBanner(LocationInfo loc) {
    if (loc.distance == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Lokasi toko belum diatur admin.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      );
    }
    final within = loc.withinRadius;
    final c = within ? AppColors.success : AppColors.danger;
    final d = loc.distance!.round();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(within ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: c, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            within
                ? 'Kamu berada dalam zona absen • $d m dari toko'
                : 'Di luar zona absen • $d m dari toko (radius ${loc.radius.round()} m)',
            style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _actionButton() {
    if (_loadingToday) return const SizedBox();
    final data = _today?.data();
    final hasClockIn = data?['clockIn'] != null;

    if (data == null || !hasClockIn) {
      return _bigButton('Absen Masuk', Icons.login_rounded, AppColors.primary, _doClockIn);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_rounded, color: AppColors.success),
        SizedBox(width: 8),
        Text('Absensi hari ini selesai',
            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _bigButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _processing ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        icon: _processing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Icon(icon),
        label: Text(_processing ? 'Memproses...' : label),
      ),
    );
  }
}
