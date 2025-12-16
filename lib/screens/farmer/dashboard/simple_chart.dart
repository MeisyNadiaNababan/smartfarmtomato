import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SensorHistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> historyData; // Data dari history
  final String title;
  final Color color;
  final String dataType; // 'temperature', 'humidity', 'soilMoisture', 'brightness'
  final int maxDataPoints; // Jumlah maksimal data yang ditampilkan

  const SensorHistoryChart({
    super.key,
    required this.historyData,
    required this.title,
    required this.color,
    required this.dataType,
    this.maxDataPoints = 20,
  });

  @override
  Widget build(BuildContext context) {
    // Filter dan sort data
    final filteredData = _filterAndSortData();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
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
          // Header dengan nilai terkini
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (filteredData.isNotEmpty)
                Text(
                  _getCurrentValue(filteredData),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Subtitle (waktu terakhir update)
          if (filteredData.isNotEmpty)
            Text(
              'Terakhir: ${_formatTime(filteredData.last['time'])}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Chart
          SizedBox(
            height: 180,
            child: filteredData.isEmpty
                ? _buildEmptyState(context)
                : LineChart(
                    LineChartData(
                      minY: _getMinY(filteredData),
                      maxY: _getMaxY(filteredData),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getYInterval(filteredData),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: _getXInterval(filteredData),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < filteredData.length) {
                                final dataPoint = filteredData[index];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _formatTimeLabel(dataPoint['time']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: _getYInterval(filteredData),
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatYValue(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: filteredData.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              _getValue(entry.value).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: filteredData.length <= 10,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: color,
                                strokeWidth: 2,
                                strokeColor: Theme.of(context).cardColor,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.4),
                                color.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Theme.of(context).cardColor,
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.all(8),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((touchedSpot) {
                              final index = touchedSpot.spotIndex;
                              if (index >= 0 && index < filteredData.length) {
                                final dataPoint = filteredData[index];
                                return LineTooltipItem(
                                  '${_formatTimeForTooltip(dataPoint['time'])}\n${_getValueWithUnit(_getValue(dataPoint))}',
                                  TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return LineTooltipItem('', const TextStyle());
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          
          // Legend
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getSensorName(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Text(
                '${filteredData.length} data',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSortData() {
    // Filter data yang valid
    final validData = historyData.where((data) {
      final value = _getValue(data);
      final time = data['time'];
      return value != null && time != null && value > 0;
    }).toList();

    // Sort berdasarkan waktu (terlama ke terbaru)
    validData.sort((a, b) {
      try {
        final timeA = DateTime.parse(a['time'] ?? '');
        final timeB = DateTime.parse(b['time'] ?? '');
        return timeA.compareTo(timeB);
      } catch (e) {
        return 0;
      }
    });

    // Ambil data terbaru sesuai maxDataPoints
    if (validData.length > maxDataPoints) {
      return validData.sublist(validData.length - maxDataPoints);
    }

    return validData;
  }

  double _getValue(Map<String, dynamic> data) {
    switch (dataType) {
      case 'temperature':
        final value = data['temperature'];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      case 'humidity':
        final value = data['humidity'];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      case 'soilMoisture':
        final value = data['soilMoisture'];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      case 'brightness':
        final value = data['brightness'];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      default:
        return 0.0;
    }
  }

  String _getCurrentValue(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 'No Data';
    
    final lastValue = _getValue(data.last);
    
    switch (dataType) {
      case 'temperature':
        return '${lastValue.toStringAsFixed(1)}°C';
      case 'humidity':
      case 'soilMoisture':
        return '${lastValue.toStringAsFixed(1)}%';
      case 'brightness':
        return '${lastValue.toStringAsFixed(1)}%';
      default:
        return lastValue.toStringAsFixed(1);
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return 'N/A';
    
    try {
      final date = DateTime.parse(time.toString());
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return time.toString();
    }
  }

  String _formatTimeLabel(dynamic time) {
    if (time == null) return '';
    
    try {
      final date = DateTime.parse(time.toString());
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      if (time.toString().length > 5) {
        return time.toString().substring(11, 16);
      }
      return time.toString();
    }
  }

  String _formatTimeForTooltip(dynamic time) {
    if (time == null) return 'N/A';
    
    try {
      final date = DateTime.parse(time.toString());
      return DateFormat('dd/MM HH:mm').format(date);
    } catch (e) {
      return time.toString();
    }
  }

  String _formatYValue(double value) {
    switch (dataType) {
      case 'temperature':
        return '${value.toInt()}°C';
      case 'humidity':
      case 'soilMoisture':
      case 'brightness':
        return '${value.toInt()}%';
      default:
        return value.toInt().toString();
    }
  }

  String _getValueWithUnit(double value) {
    switch (dataType) {
      case 'temperature':
        return '${value.toStringAsFixed(1)}°C';
      case 'humidity':
        return '${value.toStringAsFixed(1)}% RH';
      case 'soilMoisture':
        return '${value.toStringAsFixed(1)}% Soil';
      case 'brightness':
        return '${value.toStringAsFixed(1)}% Light';
      default:
        return value.toStringAsFixed(1);
    }
  }

  String _getSensorName() {
    switch (dataType) {
      case 'temperature':
        return 'Suhu';
      case 'humidity':
        return 'Kelembaban Udara';
      case 'soilMoisture':
        return 'Kelembaban Tanah';
      case 'brightness':
        return 'Kecerahan';
      default:
        return 'Sensor';
    }
  }

  double _getMinY(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      switch (dataType) {
        case 'temperature':
          return 20;
        case 'humidity':
        case 'soilMoisture':
        case 'brightness':
          return 0;
        default:
          return 0;
      }
    }

    double min = _getValue(data.first);
    for (final item in data) {
      final value = _getValue(item);
      if (value < min) min = value;
    }

    // Berikan margin
    switch (dataType) {
      case 'temperature':
        return (min - 2).clamp(15, double.infinity);
      case 'humidity':
        return (min - 5).clamp(0, 100);
      case 'soilMoisture':
        return (min - 5).clamp(0, 100);
      case 'brightness':
        return (min - 5).clamp(0, 100);
      default:
        return (min - 5).clamp(0, double.infinity);
    }
  }

  double _getMaxY(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      switch (dataType) {
        case 'temperature':
          return 40;
        case 'humidity':
        case 'soilMoisture':
        case 'brightness':
          return 100;
        default:
          return 100;
      }
    }

    double max = _getValue(data.first);
    for (final item in data) {
      final value = _getValue(item);
      if (value > max) max = value;
    }

    // Berikan margin
    switch (dataType) {
      case 'temperature':
        return max + 2;
      case 'humidity':
        return (max + 5).clamp(0, 100);
      case 'soilMoisture':
        return (max + 5).clamp(0, 100);
      case 'brightness':
        return (max + 5).clamp(0, 100);
      default:
        return max + 5;
    }
  }

  double _getYInterval(List<Map<String, dynamic>> data) {
    final range = _getMaxY(data) - _getMinY(data);

    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return 20;
  }

  double _getXInterval(List<Map<String, dynamic>> data) {
    if (data.length <= 10) return 1;
    if (data.length <= 20) return 2;
    if (data.length <= 30) return 3;
    return 5;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada data',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Kelas SimpleChart yang sudah tidak digunakan lagi (untuk kompatibilitas)
class SimpleChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final Color color;
  final String dataType;

  const SimpleChart({
    super.key,
    required this.data,
    required this.title,
    required this.color,
    required this.dataType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      '${data.last.value.toStringAsFixed(1)}${dataType == 'temperature' ? '°C' : '%'}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String label;
  final double value;

  ChartData(this.label, this.value);
}