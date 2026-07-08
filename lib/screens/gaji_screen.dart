import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class GajiScreen extends StatefulWidget {
  const GajiScreen({super.key});

  @override
  State<GajiScreen> createState() => _GajiScreenState();
}

class _GajiScreenState extends State<GajiScreen> {
  int _monthOffset = 0;
  bool _loading = true;

  double _gajiPokok = 0;
  List<Map<String, dynamic>> _tunjangan = [];
  final List<Map<String, dynamic>> _spList = [];
  final List<Map<String, dynamic>> _rewardList = [];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime start, DateTime end}) _range() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month + _monthOffset, 1);
    final end = DateTime(now.year, now.month + _monthOffset + 1, 0, 23, 59, 59);
    return (start: start, end: end);
  }

  bool _inRange(Timestamp? ts, DateTime start, DateTime end) {
    final t = ts?.toDate();
    return t != null && !t.isBefore(start) && !t.isAfter(end);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final r = _range();

    final userDoc = await db.collection('users').doc(_uid).get();
    final u = userDoc.data() ?? {};
    _gajiPokok = (u['gajiPokok'] as num?)?.toDouble() ?? 0;
    _tunjangan = ((u['tunjangan'] as List?) ?? []).cast<Map<String, dynamic>>();

    final sp = await db.collection('surat_peringatan').where('userId', isEqualTo: _uid).get();
    _spList
      ..clear()
      ..addAll(sp.docs.map((d) => d.data()).where((d) => _inRange(d['tanggal'] as Timestamp?, r.start, r.end)));

    final rw = await db.collection('reward').where('userId', isEqualTo: _uid).get();
    _rewardList
      ..clear()
      ..addAll(rw.docs.map((d) => d.data()).where((d) => _inRange(d['tanggal'] as Timestamp?, r.start, r.end)));

    if (mounted) setState(() => _loading = false);
  }

  String _rupiah(num n) => 'Rp ${NumberFormat('#,###', 'id_ID').format(n)}';

  @override
  Widget build(BuildContext context) {
    final totalTunjangan = _tunjangan.fold<double>(0, (s, t) => s + ((t['nominal'] as num?)?.toDouble() ?? 0));
    final totalSP = _spList.fold<double>(0, (s, x) => s + ((x['nominal'] as num?)?.toDouble() ?? 0));
    final totalReward = _rewardList.fold<double>(0, (s, x) => s + ((x['nominal'] as num?)?.toDouble() ?? 0));
    final total = _gajiPokok + totalTunjangan - totalSP + totalReward;

    final r = _range();
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(r.start);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slip Gaji'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _monthOffset--);
              _load();
            },
          ),
          Center(child: Text(monthLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _monthOffset >= 0
                ? null
                : () {
                    setState(() => _monthOffset++);
                    _load();
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Total banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFF43F5E)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Diterima — $monthLabel',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_rupiah(total),
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  _row('Gaji Pokok', _gajiPokok, AppColors.text),
                  _sectionDivider('Tunjangan', totalTunjangan, AppColors.success),
                  ..._tunjangan.map((t) => _detail(t['nama'] as String? ?? 'Tunjangan', (t['nominal'] as num?)?.toDouble() ?? 0, AppColors.success)),
                  if (_tunjangan.isEmpty) _emptyDetail('Tidak ada tunjangan'),

                  _sectionDivider('Reward', totalReward, AppColors.success),
                  ..._rewardList.map((x) => _detail(
                      (x['kategori'] as String?)?.isNotEmpty == true ? x['kategori'] as String : 'Reward',
                      (x['nominal'] as num?)?.toDouble() ?? 0,
                      AppColors.success)),
                  if (_rewardList.isEmpty) _emptyDetail('Tidak ada reward'),

                  _sectionDivider('Potongan SP', totalSP, AppColors.danger, minus: true),
                  ..._spList.map((x) => _detail(
                      _spLabel(x['jenis'] as String?),
                      (x['nominal'] as num?)?.toDouble() ?? 0,
                      AppColors.danger,
                      minus: true)),
                  if (_spList.isEmpty) _emptyDetail('Tidak ada potongan'),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                      Text(_rupiah(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Perhitungan: gaji pokok + tunjangan + reward − potongan SP.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
    );
  }

  String _spLabel(String? jenis) {
    return {'teguran': 'Surat Teguran', 'sp1': 'SP I', 'sp2': 'SP II', 'sp3': 'SP III'}[jenis] ?? 'SP';
  }

  Widget _row(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600)),
        Text(_rupiah(value), style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _sectionDivider(String label, double total, Color color, {bool minus = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        Text('${minus ? '−' : '+'} ${_rupiah(total)}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _detail(String label, double value, Color color, {bool minus = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.circle, size: 5, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ]),
        Text('${minus ? '−' : '+'}${_rupiah(value)}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyDetail(String text) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.border, fontStyle: FontStyle.italic)),
      );
}
