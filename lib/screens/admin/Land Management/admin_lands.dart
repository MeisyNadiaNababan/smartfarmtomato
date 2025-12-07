import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';

class AdminNodesScreen extends StatefulWidget {
  const AdminNodesScreen({super.key});

  @override
  State<AdminNodesScreen> createState() => _AdminNodesScreenState();
}

class _AdminNodesScreenState extends State<AdminNodesScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _nodes = [];
  List<Map<String, dynamic>> _filteredNodes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNodes();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadNodes() {
    _databaseRef.child('nodes').onValue.listen((event) {
      try {
        final data = event.snapshot.value;
        final List<Map<String, dynamic>> nodes = [];
        
        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              nodes.add({
                'id': key,
                'name': value['name'] ?? 'Unnamed Node',
                'uid': value['uid'] ?? 'N/A',
                'owner': value['owner'] ?? 'Unknown',
                'ownerEmail': value['ownerEmail'],
                'location': value['location'] ?? 'Unknown Location',
                'status': value['status'] ?? 'offline',
                'lastSeen': value['lastSeen'],
                'createdAt': value['createdAt'],
                'sensorData': value['sensorData'] ?? {},
              });
            }
          });
          
          setState(() {
            _nodes = nodes;
            _filteredNodes = nodes;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading nodes: $e');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredNodes = _nodes.where((node) =>
        node['name'].toLowerCase().contains(_searchQuery) ||
        node['uid'].toLowerCase().contains(_searchQuery) ||
        node['owner'].toLowerCase().contains(_searchQuery) ||
        node['location'].toLowerCase().contains(_searchQuery)
      ).toList();
    }); 
  }

  void _showAddNodeDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    final TextEditingController nameController = TextEditingController();
    final TextEditingController uidController = TextEditingController();
    final TextEditingController ownerController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        title: Text(
          'Tambah Node Baru',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Node',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uidController,
                decoration: InputDecoration(
                  labelText: 'UID Node',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerController,
                decoration: InputDecoration(
                  labelText: 'Pemilik',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Lokasi',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400]! : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400]! : Colors.black,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _addNode(
              nameController.text,
              uidController.text,
              ownerController.text,
              locationController.text,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addNode(String name, String uid, String owner, String location) async {
    if (name.isEmpty || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan UID harus diisi')),
      );
      return;
    }

    try {
      final newNodeRef = _databaseRef.child('nodes').push();
      await newNodeRef.set({
        'name': name,
        'uid': uid,
        'owner': owner,
        'location': location,
        'status': 'offline',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'sensorData': {
          'temperature': 0,
          'humidity': 0,
          'soilMoisture': 0,
          'lightIntensity': 0,
        },
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Node berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _deleteNode(String nodeId) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        title: Text(
          'Hapus Node',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus node ini?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400]! : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400]! : Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _databaseRef.child('nodes/$nodeId').remove();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Node berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNodeDetails(Map<String, dynamic> node) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.white,
        title: Text(
          node['name'],
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('UID', node['uid'], isDarkMode),
              _buildDetailItem('Pemilik', node['owner'], isDarkMode),
              _buildDetailItem('Lokasi', node['location'], isDarkMode),
              _buildDetailItem('Status', node['status'], isDarkMode),
              _buildDetailItem(
                'Terakhir Online', 
                node['lastSeen'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(node['lastSeen']).toString()
                  : 'Never',
                isDarkMode,
              ),
              const SizedBox(height: 16),
              Text(
                'Data Sensor Terkini:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              _buildSensorData(node['sensorData'], isDarkMode),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400]! : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400]! : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorData(Map<String, dynamic> sensorData, bool isDarkMode) {
    return Column(
      children: [
        _buildSensorItem('Suhu', '${sensorData['temperature'] ?? 0}°C', isDarkMode),
        _buildSensorItem('Kelembapan Udara', '${sensorData['humidity'] ?? 0}%', isDarkMode),
        _buildSensorItem('Kelembapan Tanah', '${sensorData['soilMoisture'] ?? 0}%', isDarkMode),
        _buildSensorItem('Intensitas Cahaya', '${sensorData['lightIntensity'] ?? 0} lux', isDarkMode),
      ],
    );
  }

  Widget _buildSensorItem(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120, 
            child: Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400]! : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : (Theme.of(context).colorScheme.background ?? Colors.white);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[800]! : (Theme.of(context).cardColor);
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[200]!;
    final chipColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Manajemen Node IoT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _showAddNodeDialog,
                      tooltip: 'Tambah Node',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari node...',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600],
                    ),
                    prefixIcon: Icon(Icons.search, 
                        color: isDarkMode ? Colors.grey[400]! : const Color(0xFF98A2B3)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[700]! : const Color(0xFFF2F4F7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.white : Colors.blue,
                  ))
                : _filteredNodes.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada node ditemukan',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400]! : Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNodes.length,
                        itemBuilder: (context, index) {
                          final node = _filteredNodes[index];
                          return _buildNodeCard(node, isDarkMode, textColor, borderColor, chipColor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(Map<String, dynamic> node, bool isDarkMode, Color textColor, Color borderColor, Color chipColor) {
    final isOnline = node['status'] == 'online';
    final sensorData = node['sensorData'] ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? Colors.grey[800]! : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: isOnline ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'UID: ${node['uid']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400]! : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  color: isDarkMode ? Colors.grey[800]! : Colors.white,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info, 
                              size: 20, 
                              color: isDarkMode ? Colors.white : Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Detail',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, 
                              size: 20, 
                              color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'Hapus', 
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'details') {
                      _showNodeDetails(node);
                    } else if (value == 'delete') {
                      _deleteNode(node['id']);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildInfoChip('Pemilik', node['owner'], isDarkMode, chipColor),
                _buildInfoChip('Lokasi', node['location'], isDarkMode, chipColor),
                _buildStatusChip(isOnline ? 'Online' : 'Offline', isOnline),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Data Sensor:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildSensorGrid(sensorData, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, bool isDarkMode, Color chipColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.grey[300]! : Colors.black,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? Colors.green : Colors.red,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: isOnline ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSensorGrid(Map<String, dynamic> sensorData, bool isDarkMode) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3,
      children: [
        _buildSensorItemCard(Icons.thermostat, 'Suhu', '${sensorData['temperature'] ?? 0}°C', Colors.red, isDarkMode),
        _buildSensorItemCard(Icons.water_drop, 'Udara', '${sensorData['humidity'] ?? 0}%', Colors.blue, isDarkMode),
        _buildSensorItemCard(Icons.grass, 'Tanah', '${sensorData['soilMoisture'] ?? 0}%', Colors.brown, isDarkMode),
        _buildSensorItemCard(Icons.light_mode, 'Cahaya', '${sensorData['lightIntensity'] ?? 0} lux', Colors.amber, isDarkMode),
      ],
    );
  }

  Widget _buildSensorItemCard(IconData icon, String label, String value, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isDarkMode ? 0.4 : 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[300]! : Colors.black,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}