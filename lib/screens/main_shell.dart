import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'pengajuan_screen.dart';
import 'gaji_screen.dart';
import 'tim_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final role = data?['role'] as String? ?? 'karyawan';
        final isLeader = role == 'leader';

        // Gerbang kelengkapan profil: wajib nomor HP terisi.
        final noHp = (data?['noHp'] as String?) ?? '';
        final profileComplete = (data?['profileComplete'] as bool? ?? false) && noHp.isNotEmpty;

        // Selama data belum termuat, tampilkan loading agar tidak salah gerbang.
        if (snapshot.connectionState == ConnectionState.waiting && data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // Profil belum lengkap -> hanya bisa akses Profil.
        if (data != null && !profileComplete) {
          return const ProfileScreen();
        }

        // Tab "Tim" hanya muncul untuk leader.
        final pages = <Widget>[
          const HomeScreen(),
          const HistoryScreen(),
          if (isLeader) const TimScreen(),
          const PengajuanScreen(),
          const GajiScreen(),
          const ProfileScreen(),
        ];

        final destinations = <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppColors.primary),
            label: 'Riwayat',
          ),
          if (isLeader)
            const NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded, color: AppColors.primary),
              label: 'Tim',
            ),
          const NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded, color: AppColors.primary),
            label: 'Pengajuan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded, color: AppColors.primary),
            label: 'Gaji',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profil',
          ),
        ];

        final safeIndex = _index.clamp(0, pages.length - 1);

        return Scaffold(
          body: IndexedStack(index: safeIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primaryLight,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
