import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/attendance_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: AttendanceService.userStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final u = snap.data ?? {};
          final nama = (u['nama'] as String?) ?? 'Karyawan';
          final email = (u['email'] as String?) ?? FirebaseAuth.instance.currentUser?.email ?? '';
          final foto = u['fotoProfile'] as String?;
          final noHp = (u['noHp'] as String?) ?? '';
          final cabang = (u['cabang'] as String?) ?? '-';
          final jabatan = (u['jabatan'] as String?) ?? '-';
          final shift = (u['shift'] as String?) ?? '-';
          final jadwal = (u['jadwalKerja'] as List?)?.cast<String>() ?? [];
          final needHp = noHp.isEmpty || (u['profileComplete'] as bool? ?? false) == false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: (foto != null && foto.isNotEmpty) ? NetworkImage(foto) : null,
                    child: (foto == null || foto.isEmpty)
                        ? Text(nama.isNotEmpty ? nama[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
                  Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 24),
              if (needHp)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_outline_rounded, color: Color(0xFF92400E), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Lengkapi nomor HP dulu untuk membuka menu lain (Beranda, Absensi, dll).',
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              _infoTile(Icons.phone_outlined, 'Nomor HP', noHp.isEmpty ? 'Belum diisi' : noHp,
                  onTap: () => _editNoHp(context, noHp), highlight: needHp),
              _infoTile(Icons.badge_outlined, 'Jabatan', jabatan),
              _infoTile(Icons.store_mall_directory_outlined, 'Cabang', cabang),
              _infoTile(Icons.access_time_rounded, 'Shift', shift),
              _infoTile(Icons.calendar_month_outlined, 'Jadwal Kerja',
                  jadwal.isEmpty ? '-' : jadwal.join(', ')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, {VoidCallback? onTap, bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? AppColors.warning : AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, color: AppColors.text, fontWeight: FontWeight.w600)),
        trailing: onTap != null ? const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted) : null,
        onTap: onTap,
      ),
    );
  }

  Future<void> _editNoHp(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nomor HP'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await AttendanceService.updateProfile(noHp: result);
    }
  }
}
