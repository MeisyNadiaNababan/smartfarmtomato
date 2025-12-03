import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminLandsScreen extends StatefulWidget {
  const AdminLandsScreen({super.key});

  @override
  State<AdminLandsScreen> createState() => _AdminLandsScreenState();
}

class _AdminLandsScreenState extends State<AdminLandsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> lahanList = [];
  List<Map<String, dynamic>> filtered = [];
  List<String> petaniDropdown = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadLands();
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

  // ================= LOAD LANDS =================
  Future<void> _loadLands() async {
    _db.child('lands').onValue.listen((event) {
      final temp = <Map<String, dynamic>>[];

      if (event.snapshot.exists) {
        for (var l in event.snapshot.children) {
          temp.add({
            "id": l.key,
            "name": l.child("name").value?.toString() ?? "-",
            "luas": l.child("luas").value?.toString() ?? "-",
            "owner": l.child("owner").value?.toString() ?? "-",
            "location": l.child("location").value?.toString() ?? "-",
          });
        }
      }

      setState(() {
        lahanList = temp;
        filtered = temp;
      });
    });
  }

  // ================= SEARCH =================
  void _search(String q) {
    final s = q.toLowerCase();
    setState(() {
      filtered = lahanList.where((l) {
        return l["name"].toLowerCase().contains(s) ||
            l["luas"].toLowerCase().contains(s) ||
            l["owner"].toLowerCase().contains(s) ||
            l["location"].toLowerCase().contains(s);
      }).toList();
    });
  }

  // ================= DELETE =================
  Future<void> _delete(String id) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Apakah Anda yakin ingin menghapus lahan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _db.child('lands/$id').remove();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Lahan berhasil dihapus"),
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
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      body: Column(
        children: [
          _header(),
          _table(),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Manajemen Lahan",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),
          const Text(
            "Kelola data lahan pertanian",
            style: TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 16),

          // SEARCH + BUTTON
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xffF2F4F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 156, 9, 9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Tambah Lahan"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ================= TABLE =================
  Widget _table() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _tableHeader(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        "Tidak ada data lahan",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _row(filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER TABLE =================
  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: const Row(
        children: [
          _Col("Nama Lahan", 3),
          _Col("Luas", 1),
          _Col("Petani", 2),
          _Col("Lokasi", 2),
          _Col("Aksi", 2, center: true),
        ],
      ),
    );
  }

  // ================= ROW =================
  Widget _row(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3),
        ],
      ),
      child: Row(children: [
        _Text(data["name"], 3),
        _Text(data["luas"], 1),
        _Text(data["owner"], 2),
        _Text(data["location"], 2),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pillIcon(
                Icons.edit,
                Colors.blue,
                () => _showEditDialog(data),
              ),
              const SizedBox(width: 10),
              _pillIcon(
                Icons.delete,
                Colors.red,
                () => _delete(data["id"]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ================= ICON BUTTON =================
  Widget _pillIcon(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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

  // ================= ADD DIALOG =================
  void _showAddDialog() {
    final namaCtrl = TextEditingController();
    final luasCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();
    String? selectedPetani;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setLocal) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Tambah Lahan",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    _input("Nama Lahan", namaCtrl),
                    const SizedBox(height: 10),
                    _input("Luas (ha)", luasCtrl, keyboard: TextInputType.number),
                    const SizedBox(height: 10),

                    // ================= REVISI DROPDOWN TAMBAH =================
                    DropdownButtonFormField<String>(
                      value: selectedPetani,
                      hint: const Text("Pilih Petani"),
                      items: petaniDropdown
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p,
                              child: Text(p),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedPetani = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xffF2F4F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    _input("Lokasi", lokasiCtrl),
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
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () async {
                              if (namaCtrl.text.isEmpty ||
                                  luasCtrl.text.isEmpty ||
                                  lokasiCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Semua field harus diisi"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              try {
                                await _db.child("lands").push().set({
                                  "name": namaCtrl.text,
                                  "luas": luasCtrl.text,
                                  "owner": selectedPetani ?? "-",
                                  "location": lokasiCtrl.text,
                                });
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Lahan berhasil ditambahkan"),
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
                            label: const Text("Simpan"),
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
  void _showEditDialog(Map<String, dynamic> data) {
    final namaCtrl = TextEditingController(text: data["name"]);
    final luasCtrl = TextEditingController(text: data["luas"]);
    final lokasiCtrl = TextEditingController(text: data["location"]);
    String? selectedPetani =
        data["owner"] == "-" ? null : data["owner"];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setLocal) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Edit Lahan",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    _input("Nama Lahan", namaCtrl),
                    const SizedBox(height: 10),
                    _input("Luas (ha)", luasCtrl, keyboard: TextInputType.number),
                    const SizedBox(height: 10),

                    // ================= REVISI DROPDOWN EDIT =================
                    DropdownButtonFormField<String>(
                      value: selectedPetani,
                      hint: const Text("Pilih Petani"),
                      items: petaniDropdown
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p,
                              child: Text(p),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedPetani = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xffF2F4F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    _input("Lokasi", lokasiCtrl),
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
                              if (namaCtrl.text.isEmpty ||
                                  luasCtrl.text.isEmpty ||
                                  lokasiCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Semua field harus diisi"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              try {
                                await _db.child("lands/${data['id']}").update({
                                  "name": namaCtrl.text,
                                  "luas": luasCtrl.text,
                                  "owner": selectedPetani ?? "-",
                                  "location": lokasiCtrl.text,
                                });
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Data berhasil diperbarui"),
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
                            label: const Text("Simpan"),
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

  // ================= INPUT =================
  Widget _input(
    String hint,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xff98A2B3),
          ),
          filled: true,
          fillColor: const Color(0xffF2F4F7),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ================= HEADER COLUMN =================
class _Col extends StatelessWidget {
  final String t;
  final int f;
  final bool center;

  const _Col(this.t, this.f, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: f,
      child: Text(
        t,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xff667085),
        ),
      ),
    );
  }
}

// ================= TEXT CELL =================
class _Text extends StatelessWidget {
  final String t;
  final int f;

  const _Text(this.t, this.f);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: f,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xff344054),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
