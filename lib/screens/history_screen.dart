import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  List<String> _jadwal = [];
  DateTime? _joinDate;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final u = doc.data();
    if (!mounted) return;
    setState(() {
      _jadwal = (u?['jadwalKerja'] as List?)?.cast<String>() ?? [];
      _joinDate = (u?['createdAt'] as Timestamp?)?.toDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Absensi')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('absensi')
            .where('userId', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snap.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final ta = (a.data()['tanggal'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final tb = (b.data()['tanggal'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });

          final summary = _computeMonthSummary(docs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryCard(summary),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Column(children: [
                    Icon(Icons.history_rounded, size: 56, color: AppColors.border),
                    SizedBox(height: 12),
                    Text('Belum ada riwayat absensi', style: TextStyle(color: AppColors.textMuted)),
                  ]),
                )
              else
                ...docs.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _item(d.data()),
                    )),
            ],
          );
        },
      ),
    );
  }

  /// Hitung ringkasan bulan berjalan: hadir, terlambat, alfa, off.
  Map<String, int> _computeMonthSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    int hadir = 0, terlambat = 0;
    for (final d in docs) {
      final t = (d.data()['tanggal'] as Timestamp?)?.toDate();
      if (t == null || t.isBefore(monthStart) || t.isAfter(today)) continue;
      final s = d.data()['status'] as String?;
      if (s == 'hadir') {
        hadir++;
      } else if (s == 'terlambat') {
        terlambat++;
      }
    }

    // Alfa & off dari jadwal kerja
    const hariMap = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Minggu'};
    int scheduled = 0, total = 0;
    DateTime start = monthStart;
    if (_joinDate != null && _joinDate!.isAfter(monthStart)) {
      start = DateTime(_joinDate!.year, _joinDate!.month, _joinDate!.day);
    }
    var d = start;
    while (!d.isAfter(today)) {
      total++;
      final name = hariMap[d.weekday];
      if (_jadwal.contains(name)) scheduled++;
      d = d.add(const Duration(days: 1));
    }
    final recorded = hadir + terlambat;
    final alfa = (scheduled - recorded).clamp(0, 999);
    final off = (total - scheduled).clamp(0, 999);

    return {'hadir': hadir, 'terlambat': terlambat, 'alfa': alfa, 'off': off};
  }

  Widget _summaryCard(Map<String, int> s) {
    final now = DateTime.now();
    final label = DateFormat('MMMM yyyy', 'id_ID').format(now);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ringkasan $label',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 14),
        Row(children: [
          _stat('Hadir', s['hadir']!, AppColors.success),
          _stat('Terlambat', s['terlambat']!, AppColors.warning),
          _stat('Alfa', s['alfa']!, AppColors.danger),
          _stat('Off', s['off']!, AppColors.textMuted),
        ]),
      ]),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _item(Map<String, dynamic> d) {
    final tgl = (d['tanggal'] as Timestamp?)?.toDate();
    final clockIn = (d['clockIn'] as Timestamp?)?.toDate();
    final status = d['status'] as String?;
    final foto = d['fotoClockIn'] as String?;

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: foto != null
              ? Image.network(foto, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => _avatarFallback())
              : _avatarFallback(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tgl != null ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(tgl) : '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              'Jam masuk ${clockIn != null ? DateFormat('HH:mm').format(clockIn) : '--:--'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _avatarFallback() => Container(
        width: 48,
        height: 48,
        color: AppColors.primaryLight,
        child: const Icon(Icons.person, color: AppColors.primary),
      );
}
