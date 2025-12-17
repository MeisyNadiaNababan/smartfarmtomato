import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smartfarmtomato/providers/theme_provider.dart';
import 'admin_notifications.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  // Data statistik
  int _totalFarmers = 0;
  int _totalLands = 0;
  int _activeNodes = 0;
  int _totalNodes = 0;
  int _criticalAlerts = 0;
  int _totalHarvests = 0;
  double _averageYield = 0.0;
  
  // Data sensor realtime dari current_data
  Map<String, dynamic> sensorData = {
    'suhu': 0.0,
    'status_suhu': 'Normal',
    'kelembaban_udara': 0.0,
    'status_kelembaban': 'Normal',
    'kelembaban_tanah': 0.0,
    'kategori_tanah': 'Normal',
    'kecerahan': 0.0,
    'kategori_cahaya': 'Normal',
  };

  // Data sensor sebelumnya untuk deteksi perubahan
  Map<String, dynamic> _previousSensorData = {
    'suhu': 0.0,
    'status_suhu': 'Normal',
    'kelembaban_udara': 0.0,
    'status_kelembaban': 'Normal',
    'kelembaban_tanah': 0.0,
    'kategori_tanah': 'Normal',
    'kecerahan': 0.0,
    'kategori_cahaya': 'Normal',
  };

  // Notifikasi
  int _unreadNotifications = 0;
  
  // Alert kritis dari alerts di Firebase (1 minggu terakhir) + realtime alerts
  List<Map<String, dynamic>> _criticalAlertsList = [];
  
  // Realtime alerts yang baru muncul (untuk perbedaan tampilan)
  List<String> _newRealtimeAlertIds = [];
  
  bool _isLoading = true;

  // Warna konsisten
  final Color _primaryColor = const Color(0xFF006B5D);
  final Color _secondaryColor = const Color(0xFFB8860B);
  final Color _tertiaryColor = const Color(0xFF558B2F);
  final Color _blueColor = const Color(0xFF1A237E);
  final Color _lightColor = const Color(0xFFB71C1C);
  final Color _greenColor = const Color(0xFF2E7D32);

  // Stream subscriptions
  StreamSubscription? _currentDataStream;
  StreamSubscription? _notificationsStream;
  StreamSubscription? _usersStream;
  StreamSubscription? _landsStream;
  StreamSubscription? _nodesStream;
  StreamSubscription? _harvestsStream;
  StreamSubscription? _alertsStream;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _setupNotificationListener();
    _setupRealtimeListener();
    _setupAlertsListener(); // Listener untuk alerts di Firebase
  }

  @override
  void dispose() {
    // Clean up semua stream subscriptions
    _currentDataStream?.cancel();
    _notificationsStream?.cancel();
    _usersStream?.cancel();
    _landsStream?.cancel();
    _nodesStream?.cancel();
    _harvestsStream?.cancel();
    _alertsStream?.cancel();
    super.dispose();
  }

  void _initializeDashboard() {
    _loadStatistics();
    _loadAlerts(); // Memuat alerts dari Firebase
  }

  void _setupNotificationListener() {
    _notificationsStream = AdminNotificationService.getUnreadCount().listen((count) {
      if (!mounted) return;
      
      setState(() {
        _unreadNotifications = count;
      });
    });
  }

  // Setup realtime listener dari current_data
  void _setupRealtimeListener() {
    _currentDataStream = _databaseRef.child('current_data').onValue.listen((event) {
      if (!mounted) return;
      
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          final newSensorData = {
            'suhu': _toDouble(data['suhu']),
            'status_suhu': data['status_suhu']?.toString() ?? 'Normal',
            'kelembaban_udara': _toDouble(data['kelembaban_udara']),
            'status_kelembaban': data['status_kelembaban']?.toString() ?? 'Normal',
            'kelembaban_tanah': _toDouble(data['kelembaban_tanah']),
            'kategori_tanah': data['kategori_tanah']?.toString() ?? 'Normal',
            'kecerahan': _toDouble(data['kecerahan']),
            'kategori_cahaya': data['kategori_cahaya']?.toString() ?? 'Normal',
          };

          // Deteksi perubahan status untuk generate alert
          _detectStatusChanges(_previousSensorData, newSensorData);

          setState(() {
            sensorData = newSensorData;
            _previousSensorData = Map<String, dynamic>.from(newSensorData);
            _isLoading = false;
          });
        }
      } catch (e) {
        print('❌ Admin: Error reading sensor data: $e');
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        print('⚠️ Admin: No data received, using default values');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Deteksi perubahan status sensor untuk generate alert realtime
  void _detectStatusChanges(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    
    // Cek perubahan untuk setiap sensor
    final sensors = [
      {
        'type': 'suhu',
        'value': newData['suhu'],
        'status': newData['status_suhu'],
        'old_status': oldData['status_suhu'],
        'unit': '°C',
        'category': 'temperature'
      },
      {
        'type': 'kelembaban_udara',
        'value': newData['kelembaban_udara'],
        'status': newData['status_kelembaban'],
        'old_status': oldData['status_kelembaban'],
        'unit': '%',
        'category': 'humidity'
      },
      {
        'type': 'kelembaban_tanah',
        'value': newData['kelembaban_tanah'],
        'status': newData['kategori_tanah'],
        'old_status': oldData['kategori_tanah'],
        'unit': '%',
        'category': 'soil'
      },
      {
        'type': 'kecerahan',
        'value': newData['kecerahan'],
        'status': newData['kategori_cahaya'],
        'old_status': oldData['kategori_cahaya'],
        'unit': 'lux',
        'category': 'light'
      },
    ];

    for (final sensor in sensors) {
      final newStatus = sensor['status'] as String;
      final oldStatus = sensor['old_status'] as String;
      
      // Jika status berubah dari normal ke tidak normal
      if (_isNormalStatus(oldStatus) && !_isNormalStatus(newStatus)) {
        _createRealtimeAlert(sensor, timestamp, newStatus, 'warning');
      }
      // Jika status berubah dari tidak normal ke normal
      else if (!_isNormalStatus(oldStatus) && _isNormalStatus(newStatus)) {
        _createRealtimeAlert(sensor, timestamp, newStatus, 'success');
      }
      // Jika status tetap tidak normal (monitoring berkelanjutan)
      else if (!_isNormalStatus(newStatus)) {
        // Cek apakah sudah ada alert untuk sensor ini dalam 30 menit terakhir
        final alertExists = _criticalAlertsList.any((alert) {
          if (alert['sensor_type'] == sensor['type'] && 
              alert['source'] == 'realtime_data' &&
              alert['status'] == newStatus) {
            final alertTime = DateTime.fromMillisecondsSinceEpoch(alert['timestamp']);
            final timeDiff = now.difference(alertTime);
            return timeDiff.inMinutes < 30; // Update setiap 30 menit
          }
          return false;
        });
        
        if (!alertExists) {
          _createRealtimeAlert(sensor, timestamp, newStatus, 'warning');
        }
      }
    }
  }

  // Cek apakah status termasuk kategori normal
  bool _isNormalStatus(String status) {
    final normalStatuses = [
      'normal', 'baik', 'optimal', 'ideal', 'cukup',
      'suhu siang ideal', 'suhu malam ideal', 'rh ideal'
    ];
    
    return normalStatuses.contains(status.toLowerCase());
  }

  // Buat alert realtime dari perubahan sensor
  void _createRealtimeAlert(Map<String, dynamic> sensor, int timestamp, String status, String alertType) {
    final sensorType = sensor['type'] as String;
    final sensorValue = sensor['value'];
    final unit = sensor['unit'] as String;
    final category = sensor['category'] as String;
    
    // Tentukan severity berdasarkan status
    String severity = 'low';
    String title = 'Perubahan Status Sensor';
    String message = '';
    
    switch (status.toLowerCase()) {
      case 'panas':
      case 'tinggi':
      case 'suhu > max toleransi (panas)':
      case 'rh tinggi':
      case 'sangat kering':
      case 'sangat basah':
      case 'bahaya':
      case 'risiko jamur':
        severity = 'high';
        title = '⚠️ Kondisi Kritis Terdeteksi';
        message = 'Kondisi $sensorType dalam status kritis: $status';
        break;
      case 'dingin':
      case 'rendah':
      case 'suhu < min toleransi (dingin)':
      case 'rh rendah':
      case 'kering':
      case 'basah':
      case 'terang':
      case 'redup':
      case 'remang':
        severity = 'medium';
        title = 'Perhatian: Kondisi Tidak Optimal';
        message = '$sensorType menunjukkan kondisi tidak optimal: $status';
        break;
      case 'optimal':
      case 'normal':
      case 'ideal':
      case 'baik':
        severity = 'low';
        title = '✅ Kondisi Kembali Normal';
        message = '$sensorType telah kembali ke kondisi normal: $status';
        break;
      case 'gelap':
        severity = 'medium';
        title = 'Peringatan: Intensitas Cahaya Rendah';
        message = 'Intensitas cahaya sangat rendah: $status';
        break;
    }
    
    final alertId = 'realtime_${sensorType}_${timestamp}';
    
    final newAlert = {
      'id': alertId,
      'title': title,
      'message': '$message\nNilai: $sensorValue$unit',
      'severity': severity,
      'type': alertType,
      'sensor_type': sensorType,
      'value': '$sensorValue$unit',
      'status': status,
      'category': category,
      'timestamp': timestamp,
      'source': 'realtime_data',
    };

    // Tambahkan ke daftar alert
    setState(() {
      // Cek apakah alert dengan ID yang sama sudah ada
      final existingIndex = _criticalAlertsList.indexWhere((alert) => alert['id'] == alertId);
      
      if (existingIndex >= 0) {
        // Update alert yang sudah ada
        _criticalAlertsList[existingIndex] = newAlert;
      } else {
        // Tambahkan alert baru di posisi teratas
        _criticalAlertsList.insert(0, newAlert);
        _newRealtimeAlertIds.add(alertId);
        
        // Hapus ID dari daftar new alerts setelah 5 detik
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _newRealtimeAlertIds.remove(alertId);
            });
          }
        });
      }
      
      // Update total critical alerts (hitung yang severity medium dan high)
      _criticalAlerts = _criticalAlertsList.where((alert) {
        return alert['severity'] == 'high' || alert['severity'] == 'medium';
      }).length;
      
      // Batasi hanya 20 alert terbaru
      if (_criticalAlertsList.length > 20) {
        _criticalAlertsList = _criticalAlertsList.sublist(0, 20);
      }
    });

    // Simpan ke Firebase (opsional)
    _saveAlertToFirebase(newAlert);
  }

  // Simpan alert ke Firebase
  void _saveAlertToFirebase(Map<String, dynamic> alert) {
    try {
      final alertRef = _databaseRef.child('alerts').child(alert['id']);
      alertRef.set(alert).catchError((error) {
        print('❌ Admin: Error saving alert to Firebase: $error');
      });
    } catch (e) {
      print('❌ Admin: Error in saveAlertToFirebase: $e');
    }
  }

  // Setup listener untuk alerts di Firebase (1 minggu terakhir)
  void _setupAlertsListener() {
    _alertsStream?.cancel();
    
    // Ambil data 1 minggu terakhir
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneWeekAgoTimestamp = oneWeekAgo.millisecondsSinceEpoch;
    
    _alertsStream = _databaseRef.child('alerts')
      .orderByChild('timestamp')
      .startAt(oneWeekAgoTimestamp)
      .onValue.listen((event) {
        if (!mounted) return;
        
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            _processAlertsData(data);
          } else {
            setState(() {
              // Jangan hapus realtime alerts, hanya Firebase alerts
              _criticalAlertsList.removeWhere((alert) => alert['source'] == 'firebase_alerts');
              _updateCriticalAlertsCount();
            });
          }
        } catch (e) {
          print('❌ Admin: Error reading alerts data: $e');
          setState(() {
            _criticalAlertsList.removeWhere((alert) => alert['source'] == 'firebase_alerts');
            _updateCriticalAlertsCount();
          });
        }
      });
  }

  // Update count critical alerts
  void _updateCriticalAlertsCount() {
    _criticalAlerts = _criticalAlertsList.where((alert) {
      return alert['severity'] == 'high' || alert['severity'] == 'medium';
    }).length;
  }

  // Load alerts dari Firebase (1 minggu terakhir)
  void _loadAlerts() {
    // Ambil data 1 minggu terakhir
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneWeekAgoTimestamp = oneWeekAgo.millisecondsSinceEpoch;
    
    _databaseRef.child('alerts')
      .orderByChild('timestamp')
      .startAt(oneWeekAgoTimestamp)
      .once()
      .then((event) {
        if (!mounted) return;
        
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          _processAlertsData(data);
        } else {
          setState(() {
            _criticalAlertsList.removeWhere((alert) => alert['source'] == 'firebase_alerts');
            _updateCriticalAlertsCount();
          });
        }
      })
      .catchError((error) {
        print('❌ Admin: Error loading alerts: $error');
        setState(() {
          _criticalAlertsList.removeWhere((alert) => alert['source'] == 'firebase_alerts');
          _updateCriticalAlertsCount();
        });
      });
  }

  // Proses data alerts dari Firebase
  void _processAlertsData(Map<dynamic, dynamic> data) {
    final List<Map<String, dynamic>> firebaseAlerts = [];
    final now = DateTime.now();
    
    data.forEach((key, value) {
      if (value is Map) {
        final timestamp = value['timestamp'] is int 
            ? value['timestamp'] 
            : DateTime.now().millisecondsSinceEpoch;
        
        // Cek apakah alert dalam 1 minggu terakhir
        final alertTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final timeDiff = now.difference(alertTime);
        
        if (timeDiff.inDays <= 7) {
          final title = value['title']?.toString() ?? 'Alert';
          final message = value['message']?.toString() ?? 'Tidak ada pesan';
          final severity = value['severity']?.toString() ?? 'medium';
          final type = value['type']?.toString() ?? 'warning';
          final sensorType = value['sensor_type']?.toString();
          final alertValue = value['value']?.toString();
          final status = value['status']?.toString();
          final category = value['category']?.toString() ?? 'system';
          
          firebaseAlerts.add({
            'id': key.toString(),
            'title': title,
            'message': message,
            'severity': severity,
            'type': type,
            'sensor_type': sensorType,
            'value': alertValue,
            'status': status,
            'category': category,
            'timestamp': timestamp,
            'source': 'firebase_alerts',
          });
        }
      }
    });

    // Sort by timestamp descending (terbaru di atas)
    firebaseAlerts.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    setState(() {
      // Hapus Firebase alerts yang lama
      _criticalAlertsList.removeWhere((alert) => alert['source'] == 'firebase_alerts');
      
      // Tambahkan Firebase alerts baru
      _criticalAlertsList.addAll(firebaseAlerts.take(10));
      
      // Sort ulang seluruh alerts (Firebase + realtime)
      _criticalAlertsList.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      
      // Update total critical alerts
      _updateCriticalAlertsCount();
    });
  }

  // Load statistik dengan error handling
  void _loadStatistics() {
    // Load users (petani)
    _usersStream?.cancel();
    _usersStream = _databaseRef.child('users').orderByChild('role').equalTo('farmer').onValue.listen((event) {
      if (!mounted) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _totalFarmers = data.length;
        });
      }
    });

    // Load lands
    _landsStream?.cancel();
    _landsStream = _databaseRef.child('lands').onValue.listen((event) {
      if (!mounted) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _totalLands = data.length;
        });
      }
    });

    // Load nodes dari root database (device dengan awalan "node")
    _nodesStream?.cancel();
    _nodesStream = _databaseRef.onValue.listen((event) {
      if (!mounted) return;
      
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        int totalNodes = 0;
        int activeNodes = 0;
        
        if (data != null) {
          // Loop melalui semua data di root untuk mencari device dengan awalan "node"
          data.forEach((key, value) {
            final deviceId = key.toString();
            
            // Cek apakah ini device dengan awalan "node" (seperti node001, node002)
            if (deviceId.startsWith('node')) {
              totalNodes++;
              
              // Cek status device
              if (value is Map) {
                final status = value['status']?.toString() ?? 'active';
                if (status.toLowerCase() == 'active') {
                  activeNodes++;
                }
              }
            }
          });
        }
        
        setState(() {
          _totalNodes = totalNodes;
          _activeNodes = activeNodes;
        });
      } catch (e) {
        print('❌ Admin: Error reading nodes data: $e');
      }
    });

    // Load harvests
    _harvestsStream?.cancel();
    _harvestsStream = _databaseRef.child('harvests').onValue.listen((event) {
      if (!mounted) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        double totalYield = 0;
        int harvestCount = 0;
        
        data.forEach((key, value) {
          totalYield += (value['yield'] ?? 0).toDouble();
          harvestCount++;
        });
        
        setState(() {
          _totalHarvests = harvestCount;
          _averageYield = harvestCount > 0 ? totalYield / harvestCount : 0.0;
        });
      }
    });
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Baru saja';
    
    try {
      final now = DateTime.now();
      final time = DateTime.fromMillisecondsSinceEpoch(timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0);
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit lalu';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari lalu';
      } else if (difference.inDays < 30) {
        return '${difference.inDays ~/ 7} minggu lalu';
      } else {
        return DateFormat('dd/MM/yyyy').format(time);
      }
    } catch (e) {
      return 'Baru saja';
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'panas':
      case 'tinggi':
      case 'kering':
      case 'bahaya':
      case 'suhu > max toleransi (panas)':
      case 'rh tinggi':
      case 'risiko jamur':
      case 'sangat kering':
      case 'sangat basah':
        return Colors.orange;
      case 'dingin':
      case 'rendah':
      case 'suhu < min toleransi (dingin)':
      case 'rh rendah':
        return Colors.blue;
      case 'lembab':
      case 'basah':
        return Colors.blue;
      case 'optimal':
      case 'normal':
      case 'baik':
      case 'cukup':
      case 'ideal':
      case 'suhu siang ideal':
      case 'suhu malam ideal':
      case 'rh ideal':
        return Colors.green;
      case 'terang':
        return Colors.amber;
      case 'redup':
      case 'remang':
        return Colors.orange;
      case 'gelap':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  String _getStatusDescription(String type, String status) {
    switch (type) {
      case 'suhu':
        switch (status.toLowerCase()) {
          case 'panas':
          case 'suhu > max toleransi (panas)':
            return 'Suhu terlalu tinggi untuk tanaman tomat';
          case 'dingin':
          case 'suhu < min toleransi (dingin)':
            return 'Suhu terlalu rendah untuk tanaman tomat';
          case 'suhu siang ideal':
            return 'Suhu optimal untuk siang hari';
          case 'suhu malam ideal':
            return 'Suhu optimal untuk malam hari';
          default:
            return 'Suhu optimal untuk pertumbuhan tomat';
        }
      case 'kelembaban_udara':
        switch (status.toLowerCase()) {
          case 'tinggi':
          case 'rh tinggi':
            return 'Kelembapan udara terlalu tinggi';
          case 'rendah':
          case 'rh rendah':
            return 'Kelembapan udara terlalu rendah';
          case 'risiko jamur':
            return 'Kelembapan sangat tinggi, risiko jamur';
          case 'rh ideal':
            return 'Kelembapan udara optimal';
          default:
            return 'Kelembapan udara optimal';
        }
      case 'kelembaban_tanah':
        switch (status.toLowerCase()) {
          case 'sangat kering':
          case 'kering':
            return 'Tanah terlalu kering, butuh penyiraman';
          case 'basah':
          case 'sangat basah':
            return 'Tanah terlalu basah, kurangi penyiraman';
          case 'ideal':
            return 'Kelembapan tanah optimal untuk tomat';
          default:
            return 'Kelembapan tanah optimal';
        }
      case 'kecerahan':
        switch (status.toLowerCase()) {
          case 'terang':
            return 'Cahaya sangat terang untuk tanaman';
          case 'redup':
          case 'remang':
            return 'Cahaya cukup untuk pertumbuhan';
          case 'gelap':
            return 'Cahaya terlalu redup untuk tanaman';
          default:
            return 'Intensitas cahaya optimal';
        }
      default:
        return 'Kondisi normal';
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationsSheet(),
    );
  }

  Widget _buildNotificationsSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '🔔 Notifikasi Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                StreamBuilder<int>(
                  stream: AdminNotificationService.getUnreadCount(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount > 0) {
                      return TextButton(
                        onPressed: () {
                          AdminNotificationService.markAllAsRead();
                        },
                        child: Text(
                          'Tandai Semua Dibaca',
                          style: TextStyle(
                            color: _primaryColor,
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AdminNotificationItem>>(
              stream: AdminNotificationService.getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none, 
                          size: 60, 
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada notifikasi',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Notifikasi petani baru dan reset password akan muncul di sini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final notifications = snapshot.data!;
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationItem(notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AdminNotificationItem notification) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          AdminNotificationService.markAsRead(notification.id);
        }
        // Bisa tambahkan aksi spesifik berdasarkan action
        _handleNotificationAction(notification);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead 
              ? (isDarkMode ? Colors.grey[900]! : Colors.grey[50]!)
              : _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead 
                ? Colors.grey.withOpacity(0.2)
                : _primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.typeColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.typeIcon,
                color: notification.typeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sumber: ${notification.sourceLabel}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        notification.formattedTime,
                        style: const TextStyle(
                          fontSize: 10, 
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  // Tampilkan informasi tambahan untuk password reset
                  if (notification.requestId != null && notification.category == 'password_reset')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 10, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'ID: ${notification.requestId}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tampilkan informasi petani untuk user registration
                  if (notification.userId != null && notification.category == 'user_registration')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 10, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'User: ${notification.userName}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tampilkan alasan jika ada (untuk password reset ditolak)
                  if (notification.reason != null && notification.reason!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.report, size: 10, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Alasan: ${notification.reason}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.red,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification.priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationAction(AdminNotificationItem notification) {
    // Handle aksi berdasarkan tipe notifikasi
    switch (notification.action) {
      case 'new_farmer':
        // Navigasi ke halaman manajemen petani atau detail petani
        _showFarmerDetail(notification);
        break;
      case 'password_reset_request':
        // Navigasi ke halaman manajemen reset password
        _showPasswordResetDetail(notification);
        break;
      case 'password_reset_approved':
        // Tampilkan informasi approval
        _showApprovalInfo(notification);
        break;
      case 'password_reset_rejected':
        // Tampilkan informasi penolakan
        _showRejectionInfo(notification);
        break;
    }
  }

  void _showFarmerDetail(AdminNotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Petani Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${notification.userName ?? "Tidak diketahui"}'),
            Text('Email: ${notification.userEmail ?? "Tidak diketahui"}'),
            Text('ID: ${notification.userId ?? "Tidak diketahui"}'),
            const SizedBox(height: 8),
            Text(
              'Status: Petani baru telah mendaftar',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDetail(AdminNotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${notification.userName ?? "Tidak diketahui"}'),
            Text('Email: ${notification.userEmail ?? "Tidak diketahui"}'),
            Text('ID Permintaan: ${notification.requestId ?? "Tidak diketahui"}'),
            const SizedBox(height: 8),
            Text(
              'Status: Menunggu Approval',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showApprovalInfo(AdminNotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password Disetujui'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${notification.userName ?? "Tidak diketahui"}'),
            Text('Email: ${notification.userEmail ?? "Tidak diketahui"}'),
            const SizedBox(height: 8),
            Text(
              'Status: Password telah direset',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showRejectionInfo(AdminNotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password Ditolak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${notification.userName ?? "Tidak diketahui"}'),
            Text('Email: ${notification.userEmail ?? "Tidak diketahui"}'),
            if (notification.reason != null && notification.reason!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('Alasan Penolakan:'),
                  Text(notification.reason!),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Status: Permintaan ditolak',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _getSourceLabel(String? source) {
    switch (source) {
      case 'current_data':
        return 'Data Real-time';
      case 'firebase_alerts':
        return 'Alerts Sistem';
      case 'realtime_data':
        return 'Monitoring Sensor';
      case 'registration':
        return 'Pendaftaran';
      case 'password_reset':
        return 'Reset Password';
      case 'system':
        return 'Sistem';
      default:
        return source ?? 'Sistem';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 50,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TomaFarm Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Memuat dashboard...',
                style: TextStyle(
                  fontSize: 14, 
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (!mounted) return;
            
            setState(() {
              _isLoading = true;
            });
            
            await Future.delayed(const Duration(seconds: 1));
            
            if (mounted) {
              _loadStatistics();
              _loadAlerts();
              setState(() {
                _isLoading = false;
              });
            }
          },
          color: _primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDarkMode, textColor, subtitleColor),
                const SizedBox(height: 24),
                _buildStatsGrid(isDarkMode, cardColor, textColor, subtitleColor),
                const SizedBox(height: 24),
                _buildSensorGrid(isDarkMode, cardColor, textColor, subtitleColor),
                const SizedBox(height: 24),
                _buildCriticalAlertsSection(isDarkMode, cardColor, textColor, subtitleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Administrator',
                    style: TextStyle(
                      fontSize: 16,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Farming Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              children: [
                IconButton(
                  onPressed: _showNotifications,
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications, 
                      color: _primaryColor,
                    ),
                  ),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Overview sistem dan monitoring semua lahan tomat',
          style: TextStyle(
            fontSize: 14,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDarkMode, Color cardColor, Color textColor, Color subtitleColor) {
    // Hitung status node aktif
    String nodeStatus;
    Color nodeStatusColor;
    
    if (_totalNodes == 0) {
      nodeStatus = 'Tidak Ada';
      nodeStatusColor = Colors.grey;
    } else if (_activeNodes == _totalNodes) {
      nodeStatus = 'Optimal';
      nodeStatusColor = Colors.green;
    } else if (_activeNodes >= _totalNodes / 2) {
      nodeStatus = 'Perhatian';
      nodeStatusColor = Colors.orange;
    } else {
      nodeStatus = 'Kritis';
      nodeStatusColor = Colors.red;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.power_settings_new,
              color: _primaryColor,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Statistik Sistem',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildStatCard(
              icon: Icons.people,
              title: 'Total Petani',
              value: '$_totalFarmers',
              unit: 'Orang',
              status: _totalFarmers > 0 ? 'Aktif' : 'Tidak Ada',
              color: const Color(0xFF1A237E),
              statusColor: _totalFarmers > 0 ? Colors.green : Colors.grey,
            ),
            _buildStatCard(
              icon: Icons.agriculture,
              title: 'Total Lahan',
              value: '$_totalLands',
              unit: 'Lahan',
              status: 'Terdaftar',
              color: _tertiaryColor,
              statusColor: _tertiaryColor,
            ),
            _buildStatCard(
              icon: Icons.wifi,
              title: 'Node Aktif',
              value: '$_activeNodes/$_totalNodes',
              unit: 'Node',
              status: nodeStatus,
              color: Colors.purple,
              statusColor: nodeStatusColor,
            ),
            _buildStatCard(
              icon: Icons.warning,
              title: 'Alert Kritis',
              value: '$_criticalAlerts',
              unit: 'Alert',
              status: _criticalAlerts > 0 ? 'Perhatian' : 'Aman',
              color: _lightColor,
              statusColor: _criticalAlerts > 0 ? _lightColor : Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String status,
    required Color color,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(bool isDarkMode, Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sensors,
              color: const Color.fromARGB(255, 45, 167, 49),
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Data Sensor Real-time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildSensorCard(
              icon: Icons.thermostat,
              title: 'Suhu',
              value: '${sensorData['suhu']?.toStringAsFixed(1)}°C',
              unit: 'Celcius',
              status: sensorData['status_suhu']?.toString() ?? 'Normal',
              color: const Color(0xFF006B5D),
              statusColor: _getStatusColor(
                  sensorData['status_suhu']?.toString() ?? 'Normal'),
              description: _getStatusDescription(
                  'suhu', sensorData['status_suhu']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.water_drop,
              title: 'Kelembaban Udara',
              value: '${sensorData['kelembaban_udara']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: sensorData['status_kelembaban']?.toString() ?? 'Normal',
              color: const Color(0xFFB8860B),
              statusColor: _getStatusColor(
                  sensorData['status_kelembaban']?.toString() ?? 'Normal'),
              description: _getStatusDescription('kelembaban_udara',
                  sensorData['status_kelembaban']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.grass,
              title: 'Kelembaban Tanah',
              value: '${sensorData['kelembaban_tanah']?.toStringAsFixed(1)}%',
              unit: 'Persen',
              status: sensorData['kategori_tanah']?.toString() ?? 'Normal',
              color: const Color(0xFF558B2F),
              statusColor: _getStatusColor(
                  sensorData['kategori_tanah']?.toString() ?? 'Normal'),
              description: _getStatusDescription('kelembaban_tanah',
                  sensorData['kategori_tanah']?.toString() ?? 'Normal'),
            ),
            _buildSensorCard(
              icon: Icons.light_mode,
              title: 'Intensitas Cahaya',
              value: '${sensorData['kecerahan']?.toStringAsFixed(0)}',
              unit: 'Lux',
              status: sensorData['kategori_cahaya']?.toString() ?? 'Normal',
              color: const Color(0xFFB71C1C),
              statusColor: _getStatusColor(
                  sensorData['kategori_cahaya']?.toString() ?? 'Normal'),
              description: _getStatusDescription('kecerahan',
                  sensorData['kategori_cahaya']?.toString() ?? 'Normal'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required String status,
    required Color color,
    required Color statusColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsSection(bool isDarkMode, Color cardColor, Color textColor, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: _lightColor),
              const SizedBox(width: 8),
              Text(
                'Alert Sistem (Real-time + 1 Minggu Terakhir)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _lightColor,
                ),
              ),
              const Spacer(),
              if (_criticalAlertsList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lightColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _lightColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _lightColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_criticalAlerts Alert',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _lightColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                'Alert realtime otomatis dari perubahan sensor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _criticalAlertsList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle, 
                        size: 40, 
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada alert',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tidak ada alert sistem dalam 1 minggu terakhir',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: _criticalAlertsList.map((alert) => 
                    _buildAlertItem(alert, isDarkMode, textColor, subtitleColor)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert, bool isDarkMode, Color textColor, Color subtitleColor) {
    final severity = alert['severity'];
    final color = _getSeverityColor(severity);
    final timeAgo = _formatTimeAgo(alert['timestamp']);
    final source = alert['source'] ?? 'firebase_alerts';
    final type = alert['type'] ?? 'warning';
    final sensorType = alert['sensor_type'];
    final value = alert['value'];
    final status = alert['status'];
    final category = alert['category'] ?? 'system';
    final isNew = _newRealtimeAlertIds.contains(alert['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNew ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNew ? color : color.withOpacity(0.3),
          width: isNew ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon berdasarkan tipe
              _getAlertIcon(type, color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BARU',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getSeverityLabel(severity),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alert['message'],
            style: TextStyle(
              fontSize: 12, 
              color: subtitleColor,
            ),
          ),
          // Tampilkan kategori alert
          if (category != null && category != 'system')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getCategoryIcon(category), size: 10, color: _getCategoryColor(category)),
                  const SizedBox(width: 4),
                  Text(
                    'Kategori: ${_getCategoryLabel(category)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getCategoryColor(category),
                    ),
                  ),
                ],
              ),
            ),
          // Tampilkan data sensor jika ada
          if (sensorType != null && value != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.sensors, size: 10, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${_getSensorLabel(sensorType)}: $value',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                    ),
                  ),
                  if (status != null)
                    Text(
                      ' (Status: $status)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sumber: ${_getSourceLabel(source)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 10, 
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getAlertIcon(String type, Color color) {
    switch (type) {
      case 'warning':
        return Icon(Icons.warning, size: 16, color: color);
      case 'error':
        return Icon(Icons.error, size: 16, color: color);
      case 'success':
        return Icon(Icons.check_circle, size: 16, color: color);
      case 'info':
      default:
        return Icon(Icons.info, size: 16, color: color);
    }
  }

  String _getSeverityLabel(String severity) {
    switch (severity) {
      case 'high':
        return 'TINGGI';
      case 'medium':
        return 'SEDANG';
      case 'low':
        return 'RENDAH';
      default:
        return severity.toUpperCase();
    }
  }

  String _getSensorLabel(String sensorType) {
    switch (sensorType) {
      case 'suhu':
        return 'Suhu';
      case 'kelembaban_udara':
        return 'Kelembaban Udara';
      case 'kelembaban_tanah':
        return 'Kelembaban Tanah';
      case 'kecerahan':
        return 'Intensitas Cahaya';
      default:
        return sensorType;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return _lightColor;
      case 'medium': return Colors.orange;
      case 'low': return const Color(0xFF1A237E);
      default: return Colors.grey;
    }
  }

  // Helper methods untuk kategori alert
  String _getCategoryLabel(String category) {
    switch (category) {
      case 'temperature':
        return 'Suhu';
      case 'humidity':
        return 'Kelembaban';
      case 'soil':
        return 'Tanah';
      case 'light':
        return 'Cahaya';
      case 'device':
        return 'Perangkat';
      case 'system':
        return 'Sistem';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'temperature':
        return Colors.red;
      case 'humidity':
        return Colors.blue;
      case 'soil':
        return Colors.brown;
      case 'light':
        return Colors.amber;
      case 'device':
        return Colors.purple;
      case 'system':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'soil':
        return Icons.grass;
      case 'light':
        return Icons.light_mode;
      case 'device':
        return Icons.device_hub;
      case 'system':
        return Icons.settings;
      default:
        return Icons.info;
    }
  }
}