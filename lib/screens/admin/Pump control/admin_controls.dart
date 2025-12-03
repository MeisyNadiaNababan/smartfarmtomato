// ignore_for_file: undefined_class
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminControlsScreen extends StatefulWidget {
  const AdminControlsScreen({super.key});

  @override
  State<AdminControlsScreen> createState() => _AdminControlsScreenState();
}

class _AdminControlsScreenState extends State<AdminControlsScreen> {
  // Firebase Database Reference
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // State variables
  bool isAutoMode = true;
  bool isPumpActive = false;
  bool isLampActive = false;

  // System status
  Map<String, String> systemStatus = {
    'iot': 'aktif',
    'database': 'sitrep',
    'sensor': 'aktif',
    'actuator': 'auto',
  };

  @override
  void initState() {
    super.initState();
    _loadControlStatus();
  }

  // Load control status from Firebase
  void _loadControlStatus() {
    _databaseRef.child('control').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          isPumpActive = data['pump'] == true;
          isLampActive = data['light'] == true;
          isAutoMode = data['autoMode'] == true;
          systemStatus['actuator'] = isAutoMode ? 'auto' : 'manual';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // appBar: AppBar(
      //   backgroundColor: Colors.white,
      //   elevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back, color: Colors.black),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      //   // title: const Text(
      //   //   'Kontrol Akuator',
      //   //   style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      //   // ),
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kontrol manual pompa air dan lampu tubuh',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Mode Otomatis Card
            _buildAutoModeCard(),
            const SizedBox(height: 16),

            // Kontrol Pompa Air Card
            _buildPumpControlCard(),
            const SizedBox(height: 16),

            // Kontrol Lampu Tubuh Card
            _buildLampControlCard(),
            const SizedBox(height: 16),

            // Status Sistem Card
            _buildSystemStatusCard(),
            const SizedBox(height: 16),

            // Informasi Kontrol Card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 32, 56, 43),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_suggest, color: Color(0xFF2D5F5D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAutoMode ? 'Mode Otomatis' : 'Mode Manual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAutoMode
                      ? 'Sistem mengontrol secara otomatis\nberdasarkan kondisi sensor'
                      : 'Kontrol manual diaktifkan\nAnda dapat mengatur pompa & lampu',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isAutoMode,
            onChanged: (value) {
              _toggleAutoMode();
            },
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green[200],
          ),
        ],
      ),
    );
  }

  Widget _buildPumpControlCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF01565B),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Kontrol Pompa Air',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isPumpActive ? Icons.power_settings_new : Icons.power_off,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: isAutoMode ? null : _togglePump,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPumpActive
                ? 'Pompa dalam kondisi aktif'
                : 'Pompa dalam kondisi non-aktif',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPumpActive ? Colors.green : Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPumpActive ? 'AKTIF' : 'MATI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAutoMode
                      ? 'Mode otomatis aktif - Kontrol manual dinonaktifkan'
                      : 'Mode manual - Anda dapat mengontrol pompa',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLampControlCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB5810D),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Kontrol Lampu Tubuh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isLampActive ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: isAutoMode ? null : _toggleLamp,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLampActive
                ? 'Lampu dalam kondisi aktif'
                : 'Lampu dalam kondisi non-aktif',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLampActive ? Colors.green : Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLampActive ? 'AKTIF' : 'MATI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAutoMode
                      ? 'Mode otomatis aktif - Kontrol manual dinonaktifkan'
                      : 'Mode manual - Anda dapat mengontrol lampu',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7C341F),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Status Sistem',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                  Icons.wifi, 'Koneksi\nIoT', systemStatus['iot']!),
              _buildStatusItem(
                  Icons.storage, 'Database', systemStatus['database']!),
              _buildStatusItem(
                  Icons.sensors, 'Sensor', systemStatus['sensor']!),
              _buildStatusItem(Icons.settings_input_component, 'Akuator',
                  systemStatus['actuator']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String status) {
    Color statusColor = status == 'aktif'
        ? Colors.green
        : status == 'sitrep'
            ? Colors.green
            : status == 'auto'
                ? Colors.green
                : status == 'manual'
                    ? Colors.blue
                    : Colors.grey;

    return Container(
      width: 70,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.red[800], size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.grey[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Informasi Kontrol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            '• Mode Otomatis: Sistem akan mengontrol pompa dan lampu\n  secara otomatis berdasarkan data sensor.',
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            '• Mode Manual: Anda dapat mengontrol pompa dan lampu\n  secara manual melalui kontrol tombol.',
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            '• Status real-time: Status sistem akan langsung\n  terlihat di dashboard.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[700],
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  // Firebase Backend Logic
  void _toggleAutoMode() {
    setState(() {
      isAutoMode = !isAutoMode;
      if (isAutoMode) {
        // Aktifkan pompa dan lampu otomatis saat mode otomatis diaktifkan
        isPumpActive = true;
        isLampActive = true;
      } else {
        // Matikan pompa dan lampu saat mode manual diaktifkan
        isPumpActive = false;
        isLampActive = false;
      }
    });

    // Update to Firebase
    _databaseRef.child('control/autoMode').set(isAutoMode);
    _databaseRef.child('control/pump').set(isPumpActive);
    _databaseRef.child('control/light').set(isLampActive);

    _logAction('Mode ${isAutoMode ? 'OTOMATIS' : 'MANUAL'} diaktifkan');
    if (isAutoMode) {
      _logAction('Pompa Air dan Lampu Tubuh DIHIDUPKAN (Auto Mode)');
    } else {
      _logAction('Pompa Air dan Lampu Tubuh DIMATIKAN (Manual Mode)');
    }

    _showSnackbar(
      isAutoMode
          ? 'Mode Otomatis Diaktifkan - Pompa & Lampu Menyala'
          : 'Mode Manual Diaktifkan - Pompa & Lampu Mati',
      isAutoMode ? Colors.green : Colors.orange,
    );
  }

  void _togglePump() {
    setState(() {
      isPumpActive = !isPumpActive;
    });

    // Update to Firebase
    _databaseRef.child('control/pump').set(isPumpActive);
    _logAction('Pompa Air ${isPumpActive ? 'DIHIDUPKAN' : 'DIMATIKAN'}');

    _showSnackbar(
      isPumpActive ? 'Pompa Air Diaktifkan' : 'Pompa Air Dimatikan',
      isPumpActive ? Colors.blue : Colors.grey,
    );
  }

  void _toggleLamp() {
    setState(() {
      isLampActive = !isLampActive;
    });

    // Update to Firebase
    _databaseRef.child('control/light').set(isLampActive);
    _logAction('Lampu Tubuh ${isLampActive ? 'DIHIDUPKAN' : 'DIMATIKAN'}');

    _showSnackbar(
      isLampActive ? 'Lampu Tubuh Diaktifkan' : 'Lampu Tubuh Dimatikan',
      isLampActive ? Colors.orange : Colors.grey,
    );
  }

  void _logAction(String action) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _databaseRef.child('logs').push().set({
      'timestamp': timestamp,
      'action': action,
      'type': 'control',
    });
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    // Clean up any listeners if needed
    super.dispose();
  }
}
