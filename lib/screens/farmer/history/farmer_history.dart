// ignore_for_file: undefined_class
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
  final Color _burgundy = const Color(0xFF8B2F3C);
  final Color _darkBrown = const Color(0xFF6B4423);
  final Color _purple = const Color(0xFF6A1B9A);
  
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

    // Load history data dari history_data
    _loadHistoryData();
  }

  void _handleRealtimeData(dynamic data) {
    if (data != null && data is Map) {
      setState(() {
        _realtimeData = _createLogEntry('realtime', data, DateTime.now().millisecondsSinceEpoch);
      });
    }
  }

  void _loadHistoryData() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Ambil data dari history_data
    _databaseRef.child('history_data')
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
        print('❌ Error loading history data: $e');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    });
  }

  int _parseTimestamp(Map<dynamic, dynamic> data, String key) {
    // 1. Coba dari timestamp field langsung (dalam milliseconds)
    if (data['timestamp'] != null) {
      final ts = data['timestamp'];
      if (ts is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(ts);
        if (date.year > 2020) {
          return ts;
        }
      }
      
      if (ts is String) {
        final parsed = int.tryParse(ts);
        if (parsed != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(parsed);
          if (date.year > 2020) {
            return parsed;
          }
        }
      }
    }

    // 2. Coba dari datetime field
    if (data['datetime'] != null) {
      final dateString = data['datetime'].toString();
      
      DateTime? dateTime = DateTime.tryParse(dateString);
      
      if (dateTime != null && dateTime.year > 2020) {
        return dateTime.millisecondsSinceEpoch;
      }
    }

    // 3. Parse dari key jika mengandung timestamp
    try {
      final parts = key.split('_');
      for (var part in parts) {
        if (part.length >= 10) {
          final possibleTimestamp = int.tryParse(part);
          if (possibleTimestamp != null) {
            if (possibleTimestamp < 10000000000) {
              final milliseconds = possibleTimestamp * 1000;
              final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
              if (date.year > 2020) {
                return milliseconds;
              }
            } else {
              final date = DateTime.fromMillisecondsSinceEpoch(possibleTimestamp);
              if (date.year > 2020) {
                return possibleTimestamp;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing timestamp from key: $e');
    }

    // 4. Fallback: Gunakan waktu sekarang
    final now = DateTime.now();
    print('⚠️ Using current time for entry: $key');
    return now.millisecondsSinceEpoch;
  }

  LogEntry _createLogEntry(String id, Map<dynamic, dynamic> data, int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    
    print('📅 Created entry: ${date.toString()} for id: $id');
    
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
      plantAge: data['umur_tanaman'] != null ? int.tryParse(data['umur_tanaman'].toString()) : 1,
      timeOfDay: data['waktu']?.toString(),
      datetime: data['datetime']?.toString(),
      formattedDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
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

  // Fungsi untuk mendapatkan waktu berdasarkan jam
  String _getTimeOfDayLabel(DateTime date) {
    final hour = date.hour;
    if (hour >= 5 && hour < 11) {
      return 'Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Sore';
    } else {
      return 'Malam';
    }
  }

  // Fungsi untuk mendapatkan warna berdasarkan waktu
  Color _getTimeOfDayColor(DateTime date) {
    final hour = date.hour;
    if (hour >= 5 && hour < 11) {
      return _teal; // Pagi
    } else if (hour >= 11 && hour < 15) {
      return _darkBrown; // Siang
    } else if (hour >= 15 && hour < 18) {
      return _purple; // Sore
    } else {
      return _darkGreen; // Malam
    }
  }

  // Hitung statistik
  int get _totalData => _logs.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Monitoring',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pantau Perkembangan Tanaman',
                        style: TextStyle(
                          fontSize: 12,
                          color: _gray,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _refreshData,
                    icon: Icon(Icons.refresh, color: _darkGreen, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Realtime Data Card
              if (_realtimeData != null) _buildRealtimeCard(),
              const SizedBox(height: 16),

              // History Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _burgundy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Riwayat Monitoring',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: $_totalData',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkGreen,
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
        children: [
          // Header dengan tanggal di kanan atas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SmartFarm Tomat - REALTIME',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
          const SizedBox(height: 8),
          Text(
            'Tahapan: ${log.plantStage} | Hari ke-${log.plantAge ?? 1}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          
          // Current Data Section
          Row(
            children: [
              Text(
                'Current Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Data realtime di pojok kanan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeFormat.format(date),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sensor data dalam badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRealtimeBadge('🌡️', '${log.temperature?.toStringAsFixed(1) ?? '-'}°C'),
              _buildRealtimeBadge('💧', '${log.humidity?.toStringAsFixed(1) ?? '-'}%'),
              _buildRealtimeBadge('🌱', '${log.soilMoisture?.toStringAsFixed(1) ?? '-'}%'),
              _buildRealtimeBadge('💡', '${log.brightness?.toStringAsFixed(1) ?? '-'}%'),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status pompa dan tanah (tanpa keterangan waktu)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: log.pumpStatus == 'ON' ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pompa: ${log.pumpStatus}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: log.soilCategory == 'SANGAT KERING' || log.soilCategory == 'KERING' 
                      ? Colors.red 
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tanah: ${log.soilCategory ?? '-'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeBadge(String icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
    
    // Tentukan waktu dan warna
    final timeOfDayLabel = _getTimeOfDayLabel(date);
    final cardColor = _getTimeOfDayColor(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan mode dan waktu di pojok kanan
          Row(
            children: [
              // Icon mode
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.operationMode == 'AUTO' ? Icons.auto_awesome : Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode: ${log.operationMode} - $timeOfDayLabel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.pumpStatus == 'ON' ? 'Pompa: ON' : 'Pompa: OFF'}  Tanah: ${log.soilCategory ?? '-'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeFormat.format(date),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateFormat.format(date),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Plant stage badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${log.plantStage}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Sensor data badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorBadge('🌡️', '${log.temperature?.toStringAsFixed(1) ?? '-'}°C'),
              _buildSensorBadge('💧', '${log.humidity?.toStringAsFixed(1) ?? '-'}%'),
              _buildSensorBadge('🌱', '${log.soilMoisture?.toStringAsFixed(1) ?? '-'}%'),
              _buildSensorBadge('💡', '${log.brightness?.toStringAsFixed(1) ?? '-'}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorBadge(String icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
  final int? plantAge;
  final String? timeOfDay;
  final String? datetime;
  final String? formattedDate;

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
    this.formattedDate, 
  });
}