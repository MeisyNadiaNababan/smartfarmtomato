// ignore_for_file: undefined_class, unused_field
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Warna konsisten
  static const Color _primaryColor = Color(0xFF006B5D);
  static const Color _secondaryColor = Color(0xFFB8860B);
  static const Color _tertiaryColor = Color(0xFF558B2F);
  static const Color _blueColor = Color(0xFF1A237E);
  static const Color _greenColor = Color(0xFF2E7D32);
  static const Color _accentColor = Color(0xFFB71C1C);

  // Debug monitoring
  static void startMonitoring() {
    _databaseRef.child('notifications').onValue.listen((event) {
      print('🎯 REAL-TIME UPDATE DETECTED');
      final data = event.snapshot.value;
      if (data != null) {
        print('📊 Total notifications: ${(data as Map).length}');
      }
    });
  }

  static Stream<List<NotificationItem>> getNotifications() {
    print('🔔 Starting notifications stream...');

    return _databaseRef
        .child('notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<NotificationItem> notifications = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      print('📨 Received ${data?.length ?? 0} notifications from Firebase');

      if (data != null) {
        data.forEach((key, value) {
          try {
            final timestamp = _parseTimestamp(value['timestamp']);

            // Format tanggal untuk display - PERBAIKAN: Ambil dari createdAt jika ada
            DateTime notificationDate;
            if (value['createdAt'] != null) {
              try {
                notificationDate =
                    DateTime.parse(value['createdAt'].toString());
              } catch (e) {
                notificationDate =
                    DateTime.fromMillisecondsSinceEpoch(timestamp);
              }
            } else {
              notificationDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }

            // Debug info
            print(
                '🔍 Notification: ${value['title']} - Date: ${notificationDate.toString()}');

            notifications.add(NotificationItem(
              id: key.toString(),
              title: value['title']?.toString() ?? 'Notifikasi',
              message: value['message']?.toString() ?? '',
              timestamp: timestamp,
              createdAt: value['createdAt']?.toString(),
              isRead: value['isRead'] == true,
              type: value['type']?.toString() ?? 'info',
            ));
          } catch (e) {
            print('❌ Error parsing notification $key: $e');
          }
        });
      }

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      print('✅ Processed ${notifications.length} notifications');
      return notifications;
    });
  }

  static int _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }

    int ts = 0;

    if (timestamp is int) {
      ts = timestamp;
    } else if (timestamp is String) {
      ts = int.tryParse(timestamp) ?? 0;
    }

    // ---- BLOKIR VALUE INVALID ----
    if (ts <= 0) {
      print('⚠ TIMESTAMP INVALID DETECTED → forced current time');
      return DateTime.now().millisecondsSinceEpoch;
    }

    // ---- convert seconds → milliseconds ----
    if (ts < 100000000000) {
      ts *= 1000;
    }

    return ts;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _databaseRef.child('notifications/$notificationId/isRead').set(true);
    print('✅ Marked as read: $notificationId');
  }

  static Future<void> markAllAsRead() async {
    final notifications = await _databaseRef.child('notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var key in data.keys) {
        await _databaseRef.child('notifications/$key/isRead').set(true);
      }
      print('✅ Marked all ${data.length} notifications as read');
    }
  }

  static Future<int> getUnreadCount() async {
    final notifications = await _databaseRef.child('notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;
    int count = 0;

    if (data != null) {
      data.forEach((key, value) {
        if (value['isRead'] != true) {
          count++;
        }
      });
    }

    print('📊 Unread count: $count');
    return count;
  }

  // Method untuk membuat notifikasi otomatis
  static Future<void> createAutoNotification(
      String title, String message, String type) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newRef = _databaseRef.child('notifications').push();

    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'createdAt': DateTime.now().toIso8601String(), // Tambahkan createdAt
      'isRead': false,
      'type': type,
    });

    print('🔔 Created auto notification: $title (Key: ${newRef.key})');
  }

  // Method khusus untuk notifikasi data sensor dari Wokwi
  static Future<void> createSensorNotification(
      double temperature,
      double humidity,
      double soilMoisture,
      double brightness,
      String soilCategory,
      String airHumStatus,
      String tempStatus,
      String plantStage,
      int plantAgeDays,
      bool isPumpOn) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Tentukan jenis notifikasi berdasarkan kondisi
    String type = 'info';
    String title = '🌱 Data Sensor Tomat';

    // Deteksi kondisi yang perlu perhatian
    if (temperature > 32.0) {
      type = 'warning';
      title = '🔥 Suhu Terlalu Tinggi';
    } else if (temperature < 15.0) {
      type = 'warning';
      title = '❄ Suhu Terlalu Rendah';
    } else if (soilMoisture < 30.0) {
      type = 'warning';
      title = '🏜 Tanah Sangat Kering';
    } else if (soilMoisture > 80.0) {
      type = 'warning';
      title = '💦 Tanah Terlalu Basah';
    } else if (humidity > 85.0) {
      type = 'warning';
      title = '💨 Kelembaban Tinggi';
    } else if (isPumpOn) {
      type = 'success';
      title = '🚰 Pompa Menyala';
    }

    // Format pesan notifikasi yang informatif
    String message = '';
    message += '🌡 Suhu: ${temperature.toStringAsFixed(1)}°C\n';
    message += '💧 Udara: ${humidity.toStringAsFixed(1)}% ($airHumStatus)\n';
    message +=
        '🌱 Tanah: ${soilMoisture.toStringAsFixed(1)}% ($soilCategory)\n';
    message += '💡 Cahaya: ${brightness.toStringAsFixed(1)}%\n';
    message += '📅 Tahap: $plantStage (Hari $plantAgeDays)\n';
    message += '🚰 Pompa: ${isPumpOn ? 'ON' : 'OFF'}';

    final newRef = _databaseRef.child('notifications').push();
    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'type': type,
    });

    print('🔔 Sensor notification created: $title (Key: ${newRef.key})');
  }

  // Method untuk notifikasi penyiraman
  static Future<void> createWateringNotification(
      bool isWatering, double soilMoisture, String plantStage) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String title =
        isWatering ? '🚰 Penyiraman Dimulai' : '✅ Penyiraman Selesai';
    String type = isWatering ? 'info' : 'success';

    String message = isWatering
        ? 'Pompa menyala untuk menyiram tanaman tomat\nKelembaban tanah: ${soilMoisture.toStringAsFixed(1)}%\nTahapan: $plantStage'
        : 'Penyiraman selesai\nKelembaban tanah: ${soilMoisture.toStringAsFixed(1)}%\nTahapan: $plantStage';

    final newRef = _databaseRef.child('notifications').push();
    await newRef.set({
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'type': type,
    });

    print('🔔 Watering notification created: $title');
  }

  // Test function untuk debugging
  static Future<void> sendTestNotification() async {
    await createAutoNotification(
        '🧪 Test Notification',
        'Ini adalah notifikasi test dari Flutter\nWaktu: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        'info');
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final int timestamp;
  final String? createdAt; // Tambahkan field untuk createdAt
  final bool isRead;
  final String type;

  // Warna konsisten dengan aplikasi
  static const Color _primaryColor = Color(0xFF006B5D);
  static const Color _secondaryColor = Color(0xFFB8860B);
  static const Color _tertiaryColor = Color(0xFF558B2F);
  static const Color _blueColor = Color(0xFF1A237E);
  static const Color _greenColor = Color(0xFF2E7D32);
  static const Color _accentColor = Color(0xFFB71C1C);

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.createdAt,
    required this.isRead,
    required this.type,
  });

  // PERBAIKAN: Gunakan createdAt jika ada, jika tidak gunakan timestamp
  DateTime get dateTime {
    if (createdAt != null) {
      try {
        return DateTime.parse(createdAt!);
      } catch (e) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes}m yang lalu';
    if (difference.inDays < 1) return '${difference.inHours}j yang lalu';
    if (difference.inDays < 7) return '${difference.inDays}h yang lalu';

    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String get fullFormattedTime {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // Tambahkan getter untuk tanggal yang diformat seperti contoh
  String get systemFormattedDate {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  Color get typeColor {
    switch (type) {
      case 'warning':
        return _secondaryColor;
      case 'error':
        return _accentColor;
      case 'success':
        return _tertiaryColor;
      case 'info':
      default:
        return _primaryColor;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      case 'info':
      default:
        return Icons.info;
    }
  }

  @override
  String toString() {
    return 'NotificationItem{id: $id, title: $title, date: ${dateTime.toString()}, isRead: $isRead}';
  }
}

// ============================================
// HISTORY SCREEN (TERPISAH DARI NOTIFICATION)
// ============================================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<LogEntry> _logs = [];
  LogEntry? _realtimeData;
  bool _isLoading = true;
  bool _hasError = false;

  // Warna sesuai design
  final Color _darkGreen = const Color(0xFF2D5016);
  final Color _red = const Color(0xFFB71C1C);
  final Color _blue = const Color(0xFF1565C0);
  final Color _orange = const Color(0xFFF57C00);
  final Color _teal = const Color(0xFF00695C);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _gray = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _initializeRealtimeListener();
  }

  void _initializeRealtimeListener() {
    // Listen untuk current_data (realtime)
    _databaseRef.child('current_data').onValue.listen((DatabaseEvent event) {
      _handleRealtimeData(event.snapshot.value);
    });

    // Load history data
    _loadHistoryData();
  }

  void _handleRealtimeData(dynamic data) {
    if (data != null && data is Map) {
      setState(() {
        _realtimeData = _createLogEntry(
            'realtime', data, DateTime.now().millisecondsSinceEpoch);
      });
    }
  }

  void _loadHistoryData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _databaseRef
        .child('history_data')
        .orderByKey()
        .limitToLast(100)
        .once()
        .then((DatabaseEvent event) {
      try {
        final data = event.snapshot.value;
        final List<LogEntry> logs = [];

        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              final int timestamp = _parseTimestamp(value, key.toString());
              logs.add(_createLogEntry(key.toString(), value, timestamp));
            }
          });
        }

        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    });
  }

  int _parseTimestamp(Map<dynamic, dynamic> data, String key) {
    // Coba dari timestamp
    if (data['timestamp'] != null) {
      final ts = data['timestamp'];
      if (ts is int) return ts;
      if (ts is String) {
        final parsed = int.tryParse(ts);
        if (parsed != null) return parsed;
      }
    }

    // Coba dari datetime (PERBAIKAN: format ISO 8601 dari ESP32)
    if (data['datetime'] != null) {
      final dateString = data['datetime'].toString();
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) return dateTime.millisecondsSinceEpoch;

      // Coba format manual jika ISO gagal
      if (dateString.contains('-') && dateString.contains(':')) {
        try {
          // Format: "2025-11-28 20:56:20"
          final parts = dateString.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length == 3) {
              final year = int.tryParse(dateParts[0]) ?? 2025;
              final month = int.tryParse(dateParts[1]) ?? 11;
              final day = int.tryParse(dateParts[2]) ?? 28;
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = int.tryParse(timeParts[1]) ?? 0;
              final second = int.tryParse(timeParts[2]) ?? 0;

              final manualDateTime =
                  DateTime(year, month, day, hour, minute, second);
              return manualDateTime.millisecondsSinceEpoch;
            }
          }
        } catch (e) {
          print('Error parsing manual datetime: $e');
        }
      }
    }

    // Parse dari key
    final regex = RegExp(r'(\d{10,})');
    final match = regex.firstMatch(key);
    if (match != null) {
      final millis = int.tryParse(match.group(1)!);
      if (millis != null) {
        return millis < 100000000000 ? millis * 1000 : millis;
      }
    }

    return DateTime.now().millisecondsSinceEpoch;
  }

  LogEntry _createLogEntry(
      String id, Map<dynamic, dynamic> data, int timestamp) {
    return LogEntry(
      id: id,
      timestamp: timestamp,
      temperature: _toDouble(data['suhu']),
      humidity: _toDouble(data['kelembaban_udara']),
      soilMoisture: _toDouble(data['kelembaban_tanah']),
      brightness: _toDouble(data['kecerahan']),
      soilCategory: data['kategori_tanah']?.toString(),
      operationMode: data['mode_operasi']?.toString() ?? 'AUTO',
      pumpStatus: data['status_pompa']?.toString() ?? 'OFF',
      plantStage: data['tahapan_tanaman']?.toString() ?? 'BIBIT',
      plantAge: data['umur_tanaman'] != null
          ? int.tryParse(data['umur_tanaman'].toString())
          : 1,
      timeOfDay: data['waktu']?.toString(),
      datetime: data['datetime']?.toString(),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _refreshData() {
    _loadHistoryData();
  }

  // Hitung statistik
  int get _totalData => _logs.length;
  int get _drySoilCount => _logs
      .where((log) =>
          log.soilCategory == 'SANGAT KERING' || log.soilCategory == 'KERING')
      .length;
  int get _pumpOnCount => _logs.where((log) => log.pumpStatus == 'ON').length;
  int get _autoModeCount =>
      _logs.where((log) => log.operationMode == 'AUTO').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hanya tombol refresh di pojok kanan
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _refreshData,
                  icon: Icon(Icons.refresh, color: _darkGreen),
                ),
              ),
              const SizedBox(height: 8),

              // Realtime Data Card - DIPERBAIKI untuk format seperti ESP32
              if (_realtimeData != null) _buildRealtimeCard(),
              const SizedBox(height: 16),

              // Summary Statistics Grid
              _buildSummaryGrid(),
              const SizedBox(height: 16),

              // History List
              Text(
                'Riwayat Monitoring',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _hasError
                        ? _buildErrorState()
                        : _logs.isEmpty
                            ? _buildEmptyState()
                            : _buildHistoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeCard() {
    final log = _realtimeData!;
    final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);

    // Format tanggal seperti ESP32: "2025-11-28 20:56:20"
    final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

    // Format untuk display
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan informasi sistem
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SmartFarm Tomat - REALTIME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                dateFormat.format(date),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // PERBAIKAN: Tambahkan informasi seperti ESP32
          Text(
            '🌱 Sistem Siap | ${log.plantStage} | Hari ke-${log.plantAge ?? 1}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Waktu: $formattedDateTime',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          // Data Real-Time section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Data Real-Time:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRealtimeDataItem(
                          '${log.temperature?.toStringAsFixed(1) ?? '-'}°C'),
                      _buildRealtimeDataItem(
                          '${log.humidity?.toStringAsFixed(1) ?? '-'}%'),
                      _buildRealtimeDataItem(
                          '${log.soilMoisture?.toStringAsFixed(1) ?? '-'}%'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Status bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      log.pumpStatus == 'ON'
                          ? Icons.water_drop
                          : Icons.water_drop_outlined,
                      color: log.pumpStatus == 'ON'
                          ? Colors.greenAccent
                          : Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pompa: ${log.pumpStatus}',
                      style: TextStyle(
                        color: log.pumpStatus == 'ON'
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      log.operationMode == 'AUTO'
                          ? Icons.auto_awesome
                          : Icons.settings,
                      color: log.operationMode == 'AUTO'
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mode: ${log.operationMode}',
                      style: TextStyle(
                        color: log.operationMode == 'AUTO'
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeFormat.format(date),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeDataItem(String value) {
    return Text(
      value,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(
              'Total Data', _totalData.toString(), Icons.list, _darkGreen),
          _buildSummaryItem(
              'Pompa ON', _pumpOnCount.toString(), Icons.water_drop, _blue),
          _buildSummaryItem(
              'Tanah Kering', _drySoilCount.toString(), Icons.grass, _orange),
          _buildSummaryItem(
              'Auto Mode', _autoModeCount.toString(), Icons.smart_toy, _teal),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: _gray,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.separated(
      itemCount: _logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildHistoryItem(_logs[index]);
      },
    );
  }

  Widget _buildHistoryItem(LogEntry log) {
    final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy/MM/dd');

    // Format datetime seperti ESP32 jika tersedia
    final displayDateTime =
        log.datetime ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan Mode dan waktu
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: log.operationMode == 'AUTO'
                      ? _blue.withOpacity(0.1)
                      : _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Mode: ${log.operationMode}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: log.operationMode == 'AUTO' ? _blue : _orange,
                  ),
                ),
              ),
              if (log.timeOfDay != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gray.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.timeOfDay!,
                    style: TextStyle(
                      fontSize: 10,
                      color: _gray,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                dateFormat.format(date),
                style: TextStyle(
                  color: _gray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tambahkan informasi tanaman
          if (log.plantStage.isNotEmpty)
            Text(
              '🌱 ${log.plantStage} | Hari ke-${log.plantAge ?? 1}',
              style: TextStyle(
                fontSize: 11,
                color: _darkGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '📅 $displayDateTime',
            style: TextStyle(
              fontSize: 10,
              color: _gray,
            ),
          ),
          const SizedBox(height: 12),

          // Data sensor dalam row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorItem('🌡️',
                  '${log.temperature?.toStringAsFixed(1) ?? '-'}°C', _red),
              _buildSensorItem(
                  '💧', '${log.humidity?.toStringAsFixed(0) ?? '-'}%', _blue),
              _buildSensorItem(
                  '🌱',
                  '${log.soilMoisture?.toStringAsFixed(0) ?? '-'}%',
                  _darkGreen),
              _buildSensorItem('💡',
                  '${log.brightness?.toStringAsFixed(1) ?? '-'}%', _orange),
            ],
          ),
          const SizedBox(height: 12),

          // Status bar
          Row(
            children: [
              _buildStatusChip(
                'Pompa: ${log.pumpStatus}',
                log.pumpStatus == 'ON',
                log.pumpStatus == 'ON' ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              if (log.soilCategory != null)
                _buildStatusChip(
                  'Tanah: ${log.soilCategory}',
                  false,
                  _getSoilColor(log.soilCategory!),
                ),
              const Spacer(),
              Text(
                timeFormat.format(date),
                style: TextStyle(
                  color: _gray,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorItem(String emoji, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String text, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getSoilColor(String soilCategory) {
    switch (soilCategory) {
      case 'SANGAT KERING':
        return _red;
      case 'KERING':
        return _orange;
      case 'LEMBAB':
        return _lightGreen;
      case 'BASAH':
        return _blue;
      default:
        return _gray;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _darkGreen),
          const SizedBox(height: 16),
          Text('Memuat data...', style: TextStyle(color: _darkGreen)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _red),
          const SizedBox(height: 16),
          Text('Gagal memuat data', style: TextStyle(color: _red)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Belum ada data', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class LogEntry {
  final String id;
  final int timestamp;
  final double? temperature;
  final double? humidity;
  final double? soilMoisture;
  final double? brightness;
  final String? soilCategory;
  final String operationMode;
  final String pumpStatus;
  final String plantStage;
  final int? plantAge; // Tambahkan plantAge
  final String? timeOfDay;
  final String? datetime;

  LogEntry({
    required this.id,
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.soilMoisture,
    this.brightness,
    this.soilCategory,
    required this.operationMode,
    required this.pumpStatus,
    required this.plantStage,
    this.plantAge,
    this.timeOfDay,
    this.datetime,
  });
}
