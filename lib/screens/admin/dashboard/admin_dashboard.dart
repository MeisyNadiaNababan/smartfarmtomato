import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smartfarmtomato/providers/theme_provider.dart';
import 'admin_notifications.dart';

class AdminNotificationItem {
  final String id;
  final String title;
  final String message;
  final String source;
  final bool isRead;
  final int timestamp;
  final IconData typeIcon;
  final Color typeColor;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.source,
    required this.isRead,
    required this.timestamp,
    required this.typeIcon,
    required this.typeColor,
  });

  String get formattedTime {
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h lalu';
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}

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

  // Status aktuator
  Map<String, dynamic> actuatorData = {
    'pump': false,
    'light': false,
    'autoMode': true,
  };

  // Notifikasi
  int _unreadNotifications = 0;
  
  // Alert kritis HANYA dari current_data dan history_data
  List<Map<String, dynamic>> _criticalAlertsList = [];
  
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
  StreamSubscription? _controlStream;
  StreamSubscription? _notificationsStream;
  StreamSubscription? _alertsStream;
  StreamSubscription? _usersStream;
  StreamSubscription? _landsStream;
  StreamSubscription? _nodesStream;
  StreamSubscription? _harvestsStream;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _setupNotificationListener();
    _setupRealtimeListener();
    _setupAlertListeners();
  }

  @override
  void dispose() {
    // Clean up semua stream subscriptions
    _currentDataStream?.cancel();
    _controlStream?.cancel();
    _notificationsStream?.cancel();
    _alertsStream?.cancel();
    _usersStream?.cancel();
    _landsStream?.cancel();
    _nodesStream?.cancel();
    _harvestsStream?.cancel();
    super.dispose();
  }

  void _initializeDashboard() {
    _loadStatistics();
    _loadCriticalAlerts();
  }

  void _setupNotificationListener() {
    _notificationsStream = AdminNotificationService.getNotifications().listen((notifications) {
      if (!mounted) return;
      
      final unread = notifications.where((n) => !n.isRead).length;
      setState(() {
        _unreadNotifications = unread;
      });
    });
  }

  // Setup realtime listener dari current_data dengan error handling
  void _setupRealtimeListener() {
    _currentDataStream = _databaseRef.child('current_data').onValue.listen((event) {
      if (!mounted) return;
      
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          setState(() {
            sensorData = {
              'suhu': _toDouble(data['suhu']),
              'status_suhu': data['status_suhu']?.toString() ?? 'Normal',
              'kelembaban_udara': _toDouble(data['kelembaban_udara']),
              'status_kelembaban':
                  data['status_kelembaban']?.toString() ?? 'Normal',
              'kelembaban_tanah': _toDouble(data['kelembaban_tanah']),
              'kategori_tanah': data['kategori_tanah']?.toString() ?? 'Normal',
              'kecerahan': _toDouble(data['kecerahan']),
              'kategori_cahaya':
                  data['kategori_cahaya']?.toString() ?? 'Normal',
            };
            _isLoading = false;
          });
        }
      } catch (e) {
        print('❌ Admin: Error reading sensor data: $e');
      }
    });

    _controlStream = _databaseRef.child('control').onValue.listen((event) {
      if (!mounted) return;
      
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          setState(() {
            actuatorData = {
              'pump': data['pump'] == true,
              'light': data['light'] == true,
              'autoMode': data['autoMode'] == true,
            };
          });
        }
      } catch (e) {
        print('❌ Admin: Error reading control data: $e');
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

  // Setup listener untuk alert HANYA dari current_data dan history_data
  void _setupAlertListeners() {
    _alertsStream = _databaseRef.child('admin_notifications')
      .orderByChild('type')
      .equalTo('error')
      .onValue.listen((event) {
        if (!mounted) return;
        
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final unresolvedAlerts = data.values.where((alert) => 
            alert['isRead'] != true && 
            (alert['source'] == 'current_data' || alert['source'] == 'history_data')
          ).length;
          
          setState(() {
            _criticalAlerts = unresolvedAlerts;
          });
        }
      });
  }

  // Load alert kritis HANYA dari notifikasi
  void _loadCriticalAlerts() {
    _alertsStream?.cancel(); // Cancel previous stream
    _alertsStream = _databaseRef.child('admin_notifications')
      .orderByChild('timestamp')
      .limitToLast(10)
      .onValue.listen((event) {
        if (!mounted) return;
        
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final List<Map<String, dynamic>> alerts = [];
        
        if (data != null) {
          data.forEach((key, value) {
            // Hanya ambil alert error dari current_data dan history_data
            if ((value['type'] == 'error' || value['type'] == 'warning') && 
                value['isRead'] != true &&
                (value['source'] == 'current_data' || value['source'] == 'history_data')) {
              
              alerts.add({
                'id': key.toString(),
                'title': value['title']?.toString() ?? 'Alert',
                'message': value['message']?.toString() ?? '',
                'severity': value['type'] == 'error' ? 'high' : 'medium',
                'timestamp': value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
                'source': value['source']?.toString() ?? 'system',
                'alertType': value['alertType']?.toString(),
              });
            }
          });
          
          // Sort by timestamp descending
          alerts.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
          
          setState(() {
            _criticalAlertsList = alerts.take(5).toList();
            _criticalAlerts = alerts.length;
          });
        }
      });
  }

  // Load statistik dengan error handling
  void _loadStatistics() {
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

    _nodesStream?.cancel();
    _nodesStream = _databaseRef.child('nodes').onValue.listen((event) {
      if (!mounted) return;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _activeNodes = data.values.where((node) => 
            node['status'] == 'online').length;
        });
      }
    });

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
      } else if (difference.inDays < 30) {
        return '${difference.inDays} hari lalu';
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
                  '🔔 Notifikasi Sistem',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_unreadNotifications > 0)
                  TextButton(
                    onPressed: () {
                      AdminNotificationService.markAllAsRead();
                      setState(() {
                        _unreadNotifications = 0;
                      });
                    },
                    child: Text(
                      'Tandai Semua Dibaca',
                      style: TextStyle(
                        color: _primaryColor,
                      ),
                    ),
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
              stream: AdminNotificationService.getNotifications().map(
                (list) => list.map((item) => item as AdminNotificationItem).toList(),
              ),
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
                          'Sumber: ${_getSourceLabel(notification.source)}',
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
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getSourceLabel(String? source) {
    switch (source) {
      case 'current_data':
        return 'Data Real-time';
      case 'history_data':
        return 'Data History';
      case 'registration':
        return 'Pendaftaran';
      case 'user_activity':
        return 'Aktivitas User';
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
              _loadCriticalAlerts();
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
                _buildSystemStatus(isDarkMode, cardColor, textColor),
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
              value: '$_activeNodes',
              unit: 'Node',
              status: _activeNodes == _totalLands ? 'Optimal' : 'Perhatian',
              color: Colors.purple,
              statusColor: _activeNodes == _totalLands ? Colors.green : Colors.orange,
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
              Icons.power_settings_new,
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

  Widget _buildSystemStatus(bool isDarkMode, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.engineering, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Status Sistem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSystemItem(
                icon: Icons.water_drop,
                title: 'Pompa Air',
                status: actuatorData['pump'] ? 'ON' : 'OFF',
                statusColor: actuatorData['pump'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                iconColor: Colors.blue,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              _buildSystemItem(
                icon: Icons.lightbulb,
                title: 'Lampu Tumbuh',
                status: actuatorData['light'] ? 'ON' : 'OFF',
                statusColor: actuatorData['light'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                iconColor: Colors.yellow,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              _buildSystemItem(
                icon: actuatorData['autoMode']
                    ? Icons.auto_mode
                    : Icons.engineering,
                title: 'Mode Sistem',
                status: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                statusColor:
                    actuatorData['autoMode'] ? Colors.blue : Colors.orange,
                mode: 'Aktif',
                iconColor: Colors.green,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    actuatorData['autoMode']
                        ? 'Sistem berjalan otomatis berdasarkan kondisi sensor'
                        : 'Kontrol manual aktif - Anda dapat mengontrol di halaman Kontrol',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemItem({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required String mode,
    Color? iconColor,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800]! : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDarkMode ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: iconColor ?? (isDarkMode ? Colors.white : Colors.grey[700]!),
                  size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey[300]! : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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
                'Alert Kritis',
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
                        '${_criticalAlertsList.length} Alert',
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
          const SizedBox(height: 16),
          _criticalAlertsList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle, 
                        size: 40, 
                        color: _greenColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada alert kritis',
                        style: TextStyle(
                          color: _greenColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semua sistem berjalan normal',
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
    final source = alert['source'] ?? 'system';
    final alertType = alert['alertType'] ?? 'general';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity.toUpperCase(),
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

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return _lightColor;
      case 'medium': return Colors.orange;
      case 'low': return const Color(0xFF1A237E);
      default: return Colors.grey;
    }
  }
}