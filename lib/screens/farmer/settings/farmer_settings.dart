// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../auth/home_screen.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _notificationsEnabled = true;
  bool _autoRefreshEnabled = true;
  String _userName = '';

  // Warna konsisten dengan dashboard dan history
  final Color _primaryColor = const Color(0xFF006B5D); // Warna utama
  final Color _secondaryColor = const Color(0xFFB8860B); // Warna sekunder
  final Color _tertiaryColor = const Color(0xFF558B2F); // Warna tersier
  final Color _blueColor = const Color(0xFF1A237E); // Warna biru
  final Color _greenColor = const Color(0xFF2E7D32); // Warna hijau
  final Color _accentColor = const Color(0xFFB71C1C); // Warna aksen

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserName();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _autoRefreshEnabled = prefs.getBool('autoRefresh') ?? true;
    });
  }

  void _loadUserName() {
    final user = _auth.currentUser;
    if (user != null) {
      // Cek nama di Firebase Realtime Database
      _databaseRef.child('users').child(user.uid).child('name').onValue.listen((event) {
        final nameFromDB = event.snapshot.value;
        if (nameFromDB != null && nameFromDB is String) {
          setState(() {
            _userName = nameFromDB;
          });
        } else {
          // Jika tidak ada di database, ambil dari email
          final email = user.email ?? '';
          final nameFromEmail = email.split('@').first;
          setState(() {
            _userName = nameFromEmail.isNotEmpty 
                ? nameFromEmail[0].toUpperCase() + nameFromEmail.substring(1)
                : 'Petani';
          });
        }
      });
    }
  }

  void _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    _showSnackBar('Notifikasi ${value ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  void _toggleAutoRefresh(bool value) async {
    setState(() {
      _autoRefreshEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoRefresh', value);
    _showSnackBar('Auto refresh ${value ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.edit, color: _primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Edit Nama',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nama',
                hintText: 'Masukkan nama Anda',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Nama akan ditampilkan di profil dan aplikasi',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    // Simpan nama ke Firebase Realtime Database
                    await _databaseRef.child('users').child(user.uid).update({
                      'name': nameController.text.trim(),
                    });

                    setState(() {
                      _userName = nameController.text.trim();
                    });

                    Navigator.pop(context);
                    _showSnackBar('Nama berhasil diperbarui');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memperbarui nama: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama tidak boleh kosong'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
        title: Row(
          children: [
            Icon(Icons.agriculture, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Tentang TomaFarm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.black,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '🍅 TomaFarm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart Tomato Farming System',
                      style: TextStyle(
                        fontSize: 14,
                        color: _primaryColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aplikasi TomaFarm adalah sistem monitoring dan kontrol otomatis untuk budidaya tanaman tomat. '
                'Dilengkapi dengan berbagai fitur canggih untuk memastikan tanaman tomat tumbuh optimal.',
                style: TextStyle(
                  height: 1.5,
                  color: isDarkMode
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.87)
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🎯 Fitur Utama:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem('📊 Monitoring real-time sensor', isDarkMode, context),
              _buildFeatureItem('💧 Kontrol otomatis pompa air', isDarkMode, context),
              _buildFeatureItem('💡 Kontrol lampu tumbuh', isDarkMode, context),
              _buildFeatureItem('📈 Riwayat data dan grafik', isDarkMode, context),
              _buildFeatureItem('🔔 Notifikasi cerdas', isDarkMode, context),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Informasi Teknis:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versi: 1.0.0\nBuild: 2024.12.01\nDikembangkan untuk Project Based Learning',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDarkMode, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.87)
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.logout, color: _accentColor),
            const SizedBox(width: 8),
            Text(
              'Konfirmasi Logout',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin logout dari akun Anda?',
          style: TextStyle(
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog terlebih dahulu
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await _auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat logout: $e'),
            backgroundColor: _accentColor,
          ),
        );
      }
    }
  }

  void _showAccountInfo() {
    final user = _auth.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.person, color: _blueColor),
            const SizedBox(width: 8),
            Text(
              'Informasi Akun',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountInfoItem('Nama', _userName),
            _buildAccountInfoItem('Email', user?.email ?? 'Tidak tersedia'),
            _buildAccountInfoItem(
              'Bergabung',
              user?.metadata.creationTime != null
                  ? '${DateTime.now().difference(user!.metadata.creationTime!).inDays} hari yang lalu'
                  : 'Tidak tersedia',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: _blueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _userName.isNotEmpty 
                                      ? _userName 
                                      : user?.email?.split('@').first ?? 'Petani TomaFarm',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showEditNameDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'email@example.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Petani',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showAccountInfo,
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      tooltip: 'Info Akun',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings List
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.settings, color: _primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pengaturan Aplikasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSettingItem(
                      icon: Icons.notifications_active,
                      title: 'Notifikasi Sistem',
                      subtitle: 'Terima notifikasi kondisi tanaman',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: _primaryColor,
                        activeTrackColor: _primaryColor.withOpacity(0.3),
                      ),
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildSettingItem(
                      icon: Icons.dark_mode,
                      title: 'Mode Gelap',
                      subtitle: 'Tampilan tema gelap',
                      trailing: Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          return Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleTheme(value);
                              _showSnackBar(
                                  'Mode gelap ${value ? 'diaktifkan' : 'dinonaktifkan'}');
                            },
                            activeThumbColor: _blueColor,
                            activeTrackColor: _blueColor.withOpacity(0.3),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildSettingItem(
                      icon: Icons.refresh,
                      title: 'Auto Refresh',
                      subtitle: 'Refresh data otomatis',
                      trailing: Switch(
                        value: _autoRefreshEnabled,
                        onChanged: _toggleAutoRefresh,
                        activeThumbColor: _secondaryColor,
                        activeTrackColor: _secondaryColor.withOpacity(0.3),
                      ),
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildSettingItem(
                      icon: Icons.language,
                      title: 'Bahasa',
                      subtitle: 'Bahasa Indonesia',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        _showSnackBar('Bahasa Indonesia aktif');
                      },
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildSettingItem(
                      icon: Icons.info_outline,
                      title: 'Tentang Aplikasi',
                      subtitle: 'Versi 1.0.0',
                      trailing: Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: _showAboutDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showLogoutConfirmation,
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      color: _accentColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, color: Colors.white),
                            const SizedBox(width: 12),
                            const Text(
                              'Keluar dari Akun',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _primaryColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}