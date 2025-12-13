// ignore_for_file: undefined_class
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> lahanList = [];
  List<Map<String, dynamic>> deviceList = [];
  List<Map<String, dynamic>> filtered = [];
  List<String> petaniDropdown = [];
  Map<String, Map<String, dynamic>> lahanMap = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadLahanMap();
    _loadDevices();
  }

  // ================= LOAD USERS =================
  Future<void> _loadUsers() async {
    final snap = await _db.child('users').get();
    final temp = <String>[];
    if (snap.exists) {
      for (var u in snap.children) {
        final n = u.child('name').value?.toString();
        if (n != null) temp.add(n);
      }
    }
    setState(() => petaniDropdown = temp);
  }

  // ================= LOAD LAHAN MAP =================
  Future<void> _loadLahanMap() async {
    final landsSnap = await _db.child('lands').get();
    final temp = <String, Map<String, dynamic>>{};
    if (landsSnap.exists) {
      for (var l in landsSnap.children) {
        temp[l.key ?? ""] = {
          "name": l.child("name").value?.toString() ?? "-",
          "luas": l.child("luas").value?.toString() ?? "-",
          "owner": l.child("owner").value?.toString() ?? "-",
          "location": l.child("location").value?.toString() ?? "-",
        };
      }
    }
    setState(() => lahanMap = temp);
  }

  // ================= LOAD DEVICES =================
  void _loadDevices() {
    _db.onValue.listen((event) async {
      List<Map<String, dynamic>> devices = [];
      if (event.snapshot.exists) {
        for (var snap in event.snapshot.children) {
          final deviceId = snap.key.toString();
          // Ambil hanya node001 / node002
          if (!deviceId.startsWith("node")) continue;

          // Ambil data status dari Firebase
          final deviceStatus =
              snap.child("status").value?.toString() ?? "active";
          final landKey = snap.child("landKey").value?.toString();

          Map<String, dynamic> landData;

          // Cari data lahan berdasarkan landKey jika ada
          if (landKey != null &&
              landKey.isNotEmpty &&
              lahanMap.containsKey(landKey)) {
            landData = {
              "name": lahanMap[landKey]!["name"] ?? "-",
              "luas": lahanMap[landKey]!["luas"] ?? "-",
              "owner": lahanMap[landKey]!["owner"] ?? "-",
              "location": lahanMap[landKey]!["location"] ?? "-",
            };
          } else {
            
            if (lahanMap.isNotEmpty) {
              final firstKey = lahanMap.keys.first;
              landData = {
                "name": lahanMap[firstKey]!["name"] ?? "-",
                "luas": lahanMap[firstKey]!["luas"] ?? "-",
                "owner": lahanMap[firstKey]!["owner"] ?? "-",
                "location": lahanMap[firstKey]!["location"] ?? "-",
              };
            } else {
              landData = {
                "name": "-",
                "luas": "-",
                "owner": "-",
                "location": "-",
              };
            }
          }

          devices.add({
            "deviceId": deviceId,
            "deviceName": deviceId,
            "landKey": landKey ?? "",
            "landName": landData["name"],
            "luas": landData["luas"],
            "owner": landData["owner"],
            "location": landData["location"],
            "status": deviceStatus,
          });
        }
      }
      setState(() {
        deviceList = devices;
        filtered = devices;
        _isLoading = false;
      });
    });
  }

  // ================= DELETE =================
  Future<void> _delete(String id) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Hapus perangkat ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _db.child(id).remove();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Perangkat dihapus"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ================= SEARCH =================
  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        filtered = deviceList;
      } else {
        filtered = deviceList
            .where((d) =>
                d['deviceName']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                d['landName']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                d['location']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                d['owner']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                d['status']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // ================= ADD DIALOG =================
  void _showAddDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey[400]! : const Color(0xff98A2B3);
    final inputBgColor =
        isDarkMode ? Colors.grey[800]! : const Color(0xffF2F4F7);

    final deviceNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setLocal) {
        return Dialog(
          backgroundColor: dialogBgColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Tambah Perangkat Baru",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Nama Perangkat
                    Container(
                      width: double.infinity,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: inputBgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "node",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: deviceNameCtrl,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: "001, 002, etc.",
                                hintStyle: TextStyle(color: hintColor),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Nama perangkat akan menjadi: node${deviceNameCtrl.text}",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Batal"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () async {
                              if (deviceNameCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Nomor perangkat harus diisi"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              final fullDeviceName =
                                  "node${deviceNameCtrl.text}";

                              // Cek apakah device sudah ada
                              final deviceCheck =
                                  await _db.child(fullDeviceName).get();
                              if (deviceCheck.exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Perangkat sudah ada"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              try {
                                // Buat data device baru
                                Map<String, dynamic> deviceData = {
                                  "deviceName": fullDeviceName,
                                  "status": "active",
                                  "createdAt": DateTime.now().toIso8601String(),
                                };

                                await _db.child(fullDeviceName).set(deviceData);

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Perangkat berhasil ditambahkan"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: ${e.toString()}"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Tambah"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ================= EDIT DIALOG =================
  void _showEditDialog(Map<String, dynamic> deviceData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey[400]! : const Color(0xff98A2B3);
    final inputBgColor =
        isDarkMode ? Colors.grey[800]! : const Color(0xffF2F4F7);

    String? selectedLahan = deviceData["landKey"]?.toString();
    String selectedStatus = deviceData["status"]?.toString() ?? "active";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setLocal) {
        return Dialog(
          backgroundColor: dialogBgColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit Perangkat",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nama Perangkat (read-only)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: inputBgColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.device_hub, color: hintColor, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            deviceData["deviceName"],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dropdown Status
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      hint: Text("Status", style: TextStyle(color: hintColor)),
                      dropdownColor:
                          isDarkMode ? Colors.grey[800] : Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: hintColor),
                      style: TextStyle(color: textColor),
                      items: const [
                        DropdownMenuItem<String>(
                          value: "active",
                          child: Text("Active"),
                        ),
                        DropdownMenuItem<String>(
                          value: "inactive",
                          child: Text("Inactive"),
                        ),
                        DropdownMenuItem<String>(
                          value: "maintenance",
                          child: Text("Maintenance"),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => selectedStatus = v!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBgColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: hintColor),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dropdown Lahan
                    DropdownButtonFormField<String>(
                      value: selectedLahan,
                      hint: Text("Pilih Lahan",
                          style: TextStyle(color: hintColor)),
                      dropdownColor:
                          isDarkMode ? Colors.grey[800] : Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: hintColor),
                      style: TextStyle(color: textColor),
                      items: [
                        const DropdownMenuItem<String>(
                          value: "",
                          child: Text("-- Tidak Terhubung ke Lahan --"),
                        ),
                        ...lahanMap.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  "${entry.value['name']} (${entry.value['owner']})",
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            )
                            .toList(),
                      ],
                      onChanged: (v) => setLocal(() => selectedLahan = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBgColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: hintColor),
                      ),
                    ),

                    // Info Lahan Terpilih
                    if (selectedLahan != null &&
                        selectedLahan!.isNotEmpty &&
                        lahanMap.containsKey(selectedLahan))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Info Lahan Terpilih:",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Nama: ${lahanMap[selectedLahan]!['name']}",
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                            Text(
                              "Pemilik: ${lahanMap[selectedLahan]!['owner']}",
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                            Text(
                              "Lokasi: ${lahanMap[selectedLahan]!['location']}",
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Batal"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () async {
                              try {
                                // Update data device
                                Map<String, dynamic> updates = {
                                  "status": selectedStatus,
                                };

                                // Update atau hapus landKey
                                if (selectedLahan == null ||
                                    selectedLahan!.isEmpty) {
                                  // Hapus landKey jika tidak ada lahan terpilih
                                  await _db
                                      .child(deviceData["deviceId"])
                                      .child("landKey")
                                      .remove();
                                } else {
                                  updates["landKey"] = selectedLahan;
                                }

                                await _db
                                    .child(deviceData["deviceId"])
                                    .update(updates);

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("Perangkat berhasil diperbarui"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: ${e.toString()}"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text("Update"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? Colors.grey[900] : const Color(0xffF6F7FB),
      body: Column(
        children: [
          _header(dark),
          _table(dark),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _header(bool dark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: dark ? Colors.grey[800] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Manajemen Perangkat",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Data perangkat dan relasi lahan",
            style: TextStyle(color: dark ? Colors.grey[400] : Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: Icon(Icons.search,
                        color: dark ? Colors.grey[400] : Colors.black54),
                    filled: true,
                    fillColor:
                        dark ? Colors.grey[800] : const Color(0xffF2F4F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 190, 46, 36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  minimumSize: const Size(0, 52),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Tambah Perangkat"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= TABLE =================
  Widget _table(bool dark) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _tableHeader(dark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            "Tidak ada perangkat",
                            style: TextStyle(
                                color:
                                    dark ? Colors.grey[400] : Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (c, i) => _row(i, filtered[i], dark),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TABLE HEADER =================
  Widget _tableHeader(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          _Col("No", 1),
          _Col("Nama Perangkat", 2),
          _Col("Nama Lahan", 2),
          _Col("Lokasi", 2),
          _Col("Petani", 2),
          _Col("Status", 2),
          _Col("Aksi", 2, center: true),
        ],
      ),
    );
  }

  // ================= ROW =================
  Widget _row(int index, Map<String, dynamic> d, bool dark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Text("${index + 1}", 1, dark),
          _Text(d["deviceName"], 2, dark),
          _Text(d["landName"], 2, dark),
          _Text(d["location"], 2, dark),
          _Text(d["owner"], 2, dark),
          _statusCell(d["status"], dark),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pillIcon(Icons.edit, Colors.blue, () => _showEditDialog(d)),
                const SizedBox(width: 8),
                _pillIcon(
                    Icons.delete, Colors.red, () => _delete(d["deviceId"])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STATUS CELL =================
  Widget _statusCell(String status, bool dark) {
    Color statusColor;
    String statusText;

    switch (status.toLowerCase()) {
      case "active":
        statusColor = Colors.green;
        statusText = "Active";
        break;
      case "inactive":
        statusColor = Colors.orange;
        statusText = "Inactive";
        break;
      case "maintenance":
        statusColor = Colors.blue;
        statusText = "Maintenance";
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ================= ICON BUTTON =================
  Widget _pillIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ================= TABLE COLUMN =================
class _Col extends StatelessWidget {
  final String t;
  final int f;
  final bool center;
  const _Col(this.t, this.f, {this.center = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      flex: f,
      child: Text(
        t,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

// ================= TABLE TEXT =================
class _Text extends StatelessWidget {
  final String t;
  final int f;
  final bool dark;
  const _Text(this.t, this.f, this.dark);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: f,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13,
          color: dark ? Colors.white : Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
