import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/attendance_service.dart';

class PengajuanScreen extends StatelessWidget {
  const PengajuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Cuti/Izin')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pengajuan')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snap.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.description_outlined, size: 56, color: AppColors.border),
                SizedBox(height: 12),
                Text('Belum ada pengajuan', style: TextStyle(color: AppColors.textMuted)),
                SizedBox(height: 4),
                Text('Tekan "Ajukan" untuk membuat', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _item(docs[i].data()),
          );
        },
      ),
    );
  }

  Widget _item(Map<String, dynamic> d) {
    final jenis = d['jenis'] as String? ?? '-';
    final status = d['status'] as String? ?? 'pending';
    final mulai = (d['tanggalMulai'] as Timestamp?)?.toDate();
    final selesai = (d['tanggalSelesai'] as Timestamp?)?.toDate();
    final alasan = d['alasan'] as String? ?? '';

    Color c;
    String label;
    switch (status) {
      case 'disetujui':
        c = AppColors.success;
        label = 'Disetujui';
        break;
      case 'ditolak':
        c = AppColors.danger;
        label = 'Ditolak';
        break;
      default:
        c = AppColors.warning;
        label = 'Menunggu';
    }
    final jenisLabel = {'cuti': 'Cuti', 'izin': 'Izin', 'sakit': 'Sakit'}[jenis] ?? jenis;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
            child: Text(jenisLabel, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            '${mulai != null ? DateFormat('d MMM yyyy', 'id_ID').format(mulai) : '-'}'
            ' → ${selesai != null ? DateFormat('d MMM yyyy', 'id_ID').format(selesai) : '-'}',
            style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ]),
        if (alasan.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(alasan, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ]),
    );
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _PengajuanForm(),
    );
  }
}

class _PengajuanForm extends StatefulWidget {
  const _PengajuanForm();

  @override
  State<_PengajuanForm> createState() => _PengajuanFormState();
}

class _PengajuanFormState extends State<_PengajuanForm> {
  String _jenis = 'izin';
  DateTime? _mulai;
  DateTime? _selesai;
  final _alasanCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool mulai) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: mulai ? (_mulai ?? now) : (_selesai ?? _mulai ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (mulai) {
          _mulai = picked;
          if (_selesai != null && _selesai!.isBefore(picked)) _selesai = picked;
        } else {
          _selesai = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_mulai == null || _selesai == null || _alasanCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lengkapi tanggal & alasan.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = await AttendanceService.getUserData();
      await FirebaseFirestore.instance.collection('pengajuan').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'userNama': user?['nama'] ?? '',
        'userNip': user?['nip'] ?? '',
        'jenis': _jenis,
        'tanggalMulai': Timestamp.fromDate(_mulai!),
        'tanggalSelesai': Timestamp.fromDate(_selesai!),
        'alasan': _alasanCtrl.text.trim(),
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pengajuan terkirim. Menunggu persetujuan.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengirim: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ajukan Cuti/Izin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 16),
        const Text('Jenis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Row(children: [
          _jenisChip('izin', 'Izin'),
          const SizedBox(width: 8),
          _jenisChip('cuti', 'Cuti'),
          const SizedBox(width: 8),
          _jenisChip('sakit', 'Sakit'),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dateField('Dari', _mulai, () => _pickDate(true))),
          const SizedBox(width: 10),
          Expanded(child: _dateField('Sampai', _selesai, () => _pickDate(false))),
        ]),
        const SizedBox(height: 14),
        const Text('Alasan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: _alasanCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Tulis alasan pengajuan...'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Kirim Pengajuan'),
          ),
        ),
      ]),
    );
  }

  Widget _jenisChip(String value, String label) {
    final selected = _jenis == value;
    return GestureDetector(
      onTap: () => setState(() => _jenis = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value != null ? DateFormat('d MMM yyyy', 'id_ID').format(value) : 'Pilih',
            style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}
