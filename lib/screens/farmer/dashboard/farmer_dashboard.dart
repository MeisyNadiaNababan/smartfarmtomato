import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'farmer_notifications.dart';
import 'simple_chart.dart';
import '../control/farmer_control.dart';
import '../history/farmer_history.dart';
import '../settings/farmer_settings.dart';
import '../../../providers/theme_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  late DatabaseReference _databaseRef;
  bool _isLoading = true;
  int _unreadNotifications = 0;
  bool _notificationsEnabled = true;

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

  Map<String, dynamic> actuatorData = {
    'pump': false,
    'light': false,
    'autoMode': true,
  };

  List<ChartData> temperatureData = [];
  List<ChartData> humidityData = [];
  List<ChartData> soilMoistureData = [];

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance.ref();
    _setupRealtimeListener();
    _loadNotificationSettings();
    _setupNotificationListener();
  }

  void _loadNotificationSettings() async {
    setState(() {
      _notificationsEnabled = true;
    });
  }

  void _setupNotificationListener() {
    if (_notificationsEnabled) {
      NotificationService.getNotifications().listen((notifications) {
        final unread = notifications.where((n) => !n.isRead).length;
        setState(() {
          _unreadNotifications = unread;
        });
      });
    }
  }

  void _setupRealtimeListener() {
    _databaseRef.child('current_data').onValue.listen((event) {
      try {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          print('📡 Received sensor data: $data');

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

          _updateChartData();
        }
      } catch (e) {
        print('❌ Error reading sensor data: $e');
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          print('🔍 Available keys: ${data.keys}');
        }
      }
    });

    _databaseRef.child('control').onValue.listen((event) {
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
        print('❌ Error reading control data: $e');
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        print('⚠️ No data received, using default values');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _updateChartData() {
    final now = DateTime.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      temperatureData.add(ChartData(timeLabel, sensorData['suhu']));
      humidityData.add(ChartData(timeLabel, sensorData['kelembaban_udara']));
      soilMoistureData
          .add(ChartData(timeLabel, sensorData['kelembaban_tanah']));

      if (temperatureData.length > 10) {
        temperatureData.removeAt(0);
        humidityData.removeAt(0);
        soilMoistureData.removeAt(0);
      }
    });
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
        return Colors.orange;
      case 'dingin':
      case 'rendah':
      case 'sangat kering':
      case 'suhu < min toleransi (dingin)':
      case 'rh rendah':
        return Colors.blue;
      case 'lembab':
      case 'basah':
      case 'sangat basah':
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                  '🔔 Notifikasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const Spacer(),
                if (_unreadNotifications > 0)
                  TextButton(
                    onPressed: () {
                      NotificationService.markAllAsRead();
                      setState(() {
                        _unreadNotifications = 0;
                      });
                    },
                    child: Text(
                      'Tandai Sudah Dibaca',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<NotificationItem>>(
              stream: _notificationsEnabled
                  ? NotificationService.getNotifications()
                  : Stream.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada notifikasi',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.7),
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

  Widget _buildNotificationItem(NotificationItem notification) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
              : Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.5),
                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? Theme.of(context).colorScheme.background
            : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.agriculture,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TomaFarm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Memuat data sensor...',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDarkMode ? Theme.of(context).colorScheme.background : Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _isLoading = true;
            });
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _isLoading = false;
            });
          },
          color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDarkMode),
                const SizedBox(height: 24),
                _buildSensorGrid(isDarkMode),
                const SizedBox(height: 24),
                _buildActuatorStatus(isDarkMode),
                const SizedBox(height: 24),
                _buildChartSection(isDarkMode),
                const SizedBox(height: 24),
                _buildLandInfoCard(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
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
                    'Welcome to SmartFarm Tomato',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
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
                      color: isDarkMode
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: isDarkMode ? Colors.blue[200] : Colors.blue,
                    ),
                  ),
                ),
                if (_unreadNotifications > 0 && _notificationsEnabled)
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
                        _unreadNotifications > 9
                            ? '9+'
                            : _unreadNotifications.toString(),
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
          'Monitoring realtime data pertanian tomat',
          style: TextStyle(
            fontSize: 14,
            color:
                isDarkMode ? Colors.white.withOpacity(0.6) : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSensorGrid(bool isDarkMode) {
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
            const SizedBox(width: 8), // Jarak antara icon dan teks
            Text(
              'Data Sensor Real-time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
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
              isDarkMode: isDarkMode,
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
              isDarkMode: isDarkMode,
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
              isDarkMode: isDarkMode,
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
              isDarkMode: isDarkMode,
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
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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

  Widget _buildActuatorStatus(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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
                'Status Aktuator',
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
              _buildActuatorItem(
                icon: Icons.water_drop,
                title: 'Pompa Air',
                status: actuatorData['pump'] ? 'ON' : 'OFF',
                statusColor: actuatorData['pump'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                isDarkMode: isDarkMode,
                iconColor: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildActuatorItem(
                icon: Icons.lightbulb,
                title: 'Lampu Tumbuh',
                status: actuatorData['light'] ? 'ON' : 'OFF',
                statusColor: actuatorData['light'] ? Colors.green : Colors.red,
                mode: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                isDarkMode: isDarkMode,
                iconColor: Colors.yellow,
              ),
              const SizedBox(width: 12),
              _buildActuatorItem(
                icon: actuatorData['autoMode']
                    ? Icons.auto_mode
                    : Icons.engineering,
                title: 'Mode Sistem',
                status: actuatorData['autoMode'] ? 'Auto' : 'Manual',
                statusColor:
                    actuatorData['autoMode'] ? Colors.blue : Colors.orange,
                mode: 'Aktif',
                isDarkMode: isDarkMode,
                iconColor: Colors.green,
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

  Widget _buildActuatorItem({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required String mode,
    required bool isDarkMode,
    Color? iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
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
                color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: iconColor ??
                      (isDarkMode ? Colors.white : Colors.grey[700]),
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
                color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                isDarkMode ? Colors.grey[800]! : Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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
              Icon(Icons.trending_up,
                  color: isDarkMode ? Colors.blue[200] : Colors.blue),
              const SizedBox(width: 8),
              Text(
                '📈 Trend Data Sensor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.blue[200] : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (temperatureData.isNotEmpty)
            SimpleChart(
              data: temperatureData,
              title: 'Suhu (°C)',
              color: const Color(0xFF006B5D),
              dataType: 'temperature',
            ),
          if (temperatureData.isNotEmpty) const SizedBox(height: 16),
          if (humidityData.isNotEmpty)
            SimpleChart(
              data: humidityData,
              title: 'Kelembaban Udara (%)',
              color: const Color(0xFFB8860B),
              dataType: 'humidity',
            ),
          if (humidityData.isNotEmpty) const SizedBox(height: 16),
          if (soilMoistureData.isNotEmpty)
            SimpleChart(
              data: soilMoistureData,
              title: 'Kelembaban Tanah (%)',
              color: const Color(0xFF558B2F),
              dataType: 'soilMoisture',
            ),
          if (temperatureData.isEmpty &&
              humidityData.isEmpty &&
              soilMoistureData.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text(
                'Menunggu data sensor...',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[500],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandInfoCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
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
              Icon(Icons.landscape,
                  color: isDarkMode ? Colors.green[200] : Colors.green),
              const SizedBox(width: 8),
              Text(
                'Info Lahan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.green[200] : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.edit_location, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Nama Lahan: Lahan Contoh',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Lokasi: Desa Contoh, Kecamatan Contoh',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'images/maps.png', 
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
