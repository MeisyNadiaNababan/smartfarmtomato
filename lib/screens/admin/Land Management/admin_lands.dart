import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
    final TextEditingController nameController = TextEditingController();
    final TextEditingController uidController = TextEditingController();
    final TextEditingController ownerController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Node Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Node',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uidController,
                decoration: const InputDecoration(
                  labelText: 'UID Node',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(
                  labelText: 'Pemilik',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Node'),
        content: const Text('Apakah Anda yakin ingin menghapus node ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(node['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('UID', node['uid']),
              _buildDetailItem('Pemilik', node['owner']),
              _buildDetailItem('Lokasi', node['location']),
              _buildDetailItem('Status', node['status']),
              _buildDetailItem(
                'Terakhir Online', 
                node['lastSeen'] != null 
                  ? DateTime.fromMillisecondsSinceEpoch(node['lastSeen']).toString()
                  : 'Never'
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Sensor Terkini:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildSensorData(node['sensorData']),
            ],
          ),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSensorData(Map<String, dynamic> sensorData) {
    return Column(
      children: [
        _buildSensorItem('Suhu', '${sensorData['temperature'] ?? 0}°C'),
        _buildSensorItem('Kelembapan Udara', '${sensorData['humidity'] ?? 0}%'),
        _buildSensorItem('Kelembapan Tanah', '${sensorData['soilMoisture'] ?? 0}%'),
        _buildSensorItem('Intensitas Cahaya', '${sensorData['lightIntensity'] ?? 0} lux'),
      ],
    );
  }

  Widget _buildSensorItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Text(value),
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Manajemen Node IoT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNodes.isEmpty
                    ? const Center(child: Text('Tidak ada node ditemukan'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNodes.length,
                        itemBuilder: (context, index) {
                          final node = _filteredNodes[index];
                          return _buildNodeCard(node);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(Map<String, dynamic> node) {
    final isOnline = node['status'] == 'online';
    final sensorData = node['sensorData'] ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'UID: ${node['uid']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 20),
                          SizedBox(width: 8),
                          Text('Detail'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
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
                _buildInfoChip('Pemilik', node['owner']),
                _buildInfoChip('Lokasi', node['location']),
                _buildStatusChip(isOnline ? 'Online' : 'Offline', isOnline),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Sensor:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildSensorGrid(sensorData),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12),
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

  Widget _buildSensorGrid(Map<String, dynamic> sensorData) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3,
      children: [
        _buildSensorItemCard(Icons.thermostat, 'Suhu', '${sensorData['temperature'] ?? 0}°C', Colors.red),
        _buildSensorItemCard(Icons.water_drop, 'Udara', '${sensorData['humidity'] ?? 0}%', Colors.blue),
        _buildSensorItemCard(Icons.grass, 'Tanah', '${sensorData['soilMoisture'] ?? 0}%', Colors.brown),
        _buildSensorItemCard(Icons.light_mode, 'Cahaya', '${sensorData['lightIntensity'] ?? 0} lux', Colors.amber),
      ],
    );
  }

  Widget _buildSensorItemCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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