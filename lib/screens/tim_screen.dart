import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

const _hariOptions = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

class TimScreen extends StatefulWidget {
  const TimScreen({super.key});

  @override
  State<TimScreen> createState() => _TimScreenState();
}

class _TimScreenState extends State<TimScreen> {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  String? _cabang;
  List<String> _shifts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _team = [];
  Map<String, String> _todayStatus = {}; // userId -> status

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final me = await _db.collection('users').doc(_uid).get();
    _cabang = me.data()?['cabang'] as String?;

    // Shift master untuk dropdown
    final shiftSnap = await _db.collection('shifts').get();
    _shifts = shiftSnap.docs.map((d) => d.data()['nama'] as String? ?? '').where((s) => s.isNotEmpty).toList();

    // Karyawan di cabang yang sama (query by cabang, filter role di client)
    if (_cabang != null && _cabang!.isNotEmpty) {
      final snap = await _db.collection('users').where('cabang', isEqualTo: _cabang).get();
      _team = snap.docs.where((d) {
        final role = d.data()['role'] as String?;
        return role == 'karyawan' && d.id != _uid;
      }).toList();
      _team.sort((a, b) => (a.data()['nama'] as String? ?? '').compareTo(b.data()['nama'] as String? ?? ''));

      // Status absensi hari ini
      await _loadTodayStatus();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTodayStatus() async {
    _todayStatus = {};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    for (final k in _team) {
      final snap = await _db.collection('absensi').where('userId', isEqualTo: k.id).get();
      for (final d in snap.docs) {
        final t = (d.data()['tanggal'] as Timestamp?)?.toDate();
        if (t != null && !t.isBefore(start) && t.isBefore(end)) {
          _todayStatus[k.id] = d.data()['status'] as String? ?? 'hadir';
          break;
        }
      }
    }
  }

  Future<void> _editJadwal(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final selectedDays = List<String>.from((data['jadwalKerja'] as List?) ?? []);
    String? selectedShift = data['shift'] as String?;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(data['nama'] as String? ?? 'Karyawan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                  Text('Atur shift & hari kerja', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 20),

                  const Text('Shift Kerja', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _shifts.contains(selectedShift) ? selectedShift : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    ),
                    hint: const Text('Pilih shift'),
                    items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setSheet(() => selectedShift = v),
                  ),
                  const SizedBox(height: 20),

                  const Text('Hari Kerja', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hariOptions.map((h) {
                      final checked = selectedDays.contains(h);
                      return FilterChip(
                        label: Text(h),
                        selected: checked,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: checked ? AppColors.primary : AppColors.textMuted,
                          fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(color: checked ? AppColors.primary : AppColors.border),
                        onSelected: (v) => setSheet(() {
                          if (v) {
                            selectedDays.add(h);
                          } else {
                            selectedDays.remove(h);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Simpan Jadwal'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      await _db.collection('users').doc(doc.id).update({
        'shift': selectedShift,
        'jadwalKerja': selectedDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jadwal ${data['nama']} disimpan'), backgroundColor: AppColors.success),
        );
      }
      _load();
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'hadir':
        return AppColors.success;
      case 'terlambat':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tim Saya'),
        bottom: _cabang == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_mall_directory_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_cabang!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : (_cabang == null || _cabang!.isEmpty)
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Cabang belum diatur untuk akun Anda.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              : _team.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Belum ada karyawan di cabang ini.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _team.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final k = _team[i];
                          final data = k.data();
                          final nama = data['nama'] as String? ?? 'Karyawan';
                          final shift = data['shift'] as String? ?? '-';
                          final jadwal = List<String>.from((data['jadwalKerja'] as List?) ?? []);
                          final status = _todayStatus[k.id];

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primaryLight,
                                      backgroundImage: (data['fotoProfile'] as String?)?.isNotEmpty == true
                                          ? NetworkImage(data['fotoProfile'] as String)
                                          : null,
                                      child: (data['fotoProfile'] as String?)?.isNotEmpty == true
                                          ? null
                                          : Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nama,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(shift, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status == null ? 'Belum absen' : status[0].toUpperCase() + status.substring(1),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        jadwal.isEmpty ? 'Belum ada jadwal' : jadwal.join(', '),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _editJadwal(k),
                                      icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                                      label: const Text('Atur Jadwal'),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
