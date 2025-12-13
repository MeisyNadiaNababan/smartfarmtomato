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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final scaffoldBgColor =
        isDarkMode ? Colors.grey[900]! : const Color(0xffF6F7FB);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400]! : Colors.black54;
    final inputBgColor =
        isDarkMode ? Colors.grey[800]! : const Color(0xffF2F4F7);
    final shadowColor = isDarkMode ? Colors.black : Colors.black12;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Column(
        children: [
          _header(isDarkMode, cardColor, textColor, secondaryTextColor,
              inputBgColor, shadowColor),
          _table(isDarkMode, cardColor, textColor, secondaryTextColor,
              shadowColor),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _header(bool isDarkMode, Color cardColor, Color textColor,
      Color secondaryTextColor, Color inputBgColor, Color shadowColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Manajemen Lahan",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
          ),

          const SizedBox(height: 4),
          Text(
            "Kelola data lahan pertanian",
            style: TextStyle(color: secondaryTextColor),
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
                    hintStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: Icon(Icons.search, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: textColor),
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
  Widget _table(bool isDarkMode, Color cardColor, Color textColor,
      Color secondaryTextColor, Color shadowColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _tableHeader(
                isDarkMode, cardColor, shadowColor, secondaryTextColor),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        "Tidak ada data lahan",
                        style:
                            TextStyle(color: secondaryTextColor, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _row(filtered[i], isDarkMode,
                          cardColor, textColor, shadowColor),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER TABLE =================
  Widget _tableHeader(
      bool isDarkMode, Color cardColor, Color shadowColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          _Col("Nama Lahan", 3, textColor: textColor),
          _Col("Luas", 1, textColor: textColor),
          _Col("Petani", 2, textColor: textColor),
          _Col("Lokasi", 2, textColor: textColor),
          _Col("Aksi", 2, center: true, textColor: textColor),
        ],
      ),
    );
  }

  // ================= ROW =================
  Widget _row(Map<String, dynamic> data, bool isDarkMode, Color cardColor,
      Color textColor, Color shadowColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 3),
        ],
      ),
      child: Row(children: [
        _Text(data["name"], 3, textColor: textColor),
        _Text(data["luas"], 1, textColor: textColor),
        _Text(data["owner"], 2, textColor: textColor),
        _Text(data["location"], 2, textColor: textColor),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey[400]! : const Color(0xff98A2B3);
    final inputBgColor =
        isDarkMode ? Colors.grey[800]! : const Color(0xffF2F4F7);

    final namaCtrl = TextEditingController();
    final luasCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();
    String? selectedPetani;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setLocal) {
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
                      "Tambah Lahan",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _input("Nama Lahan", namaCtrl,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
                    const SizedBox(height: 10),
                    _input("Luas (ha)", luasCtrl,
                        keyboard: TextInputType.number,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
                    const SizedBox(height: 10),

                    // DROPDOWN TAMBAH
                    DropdownButtonFormField<String>(
                      value: selectedPetani,
                      hint: Text("Pilih Petani",
                          style: TextStyle(color: hintColor)),
                      dropdownColor:
                          isDarkMode ? Colors.grey[800] : Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: hintColor),
                      style: TextStyle(color: textColor),
                      items: petaniDropdown
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p,
                              child:
                                  Text(p, style: TextStyle(color: textColor)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedPetani = v),
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
                    _input("Lokasi", lokasiCtrl,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
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
                                      content:
                                          Text("Lahan berhasil ditambahkan"),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey[400]! : const Color(0xff98A2B3);
    final inputBgColor =
        isDarkMode ? Colors.grey[800]! : const Color(0xffF2F4F7);

    final namaCtrl = TextEditingController(text: data["name"]);
    final luasCtrl = TextEditingController(text: data["luas"]);
    final lokasiCtrl = TextEditingController(text: data["location"]);
    String? selectedPetani = data["owner"] == "-" ? null : data["owner"];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setLocal) {
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
                      "Edit Lahan",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _input("Nama Lahan", namaCtrl,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
                    const SizedBox(height: 10),
                    _input("Luas (ha)", luasCtrl,
                        keyboard: TextInputType.number,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
                    const SizedBox(height: 10),

                    // DROPDOWN EDIT
                    DropdownButtonFormField<String>(
                      value: selectedPetani,
                      hint: Text("Pilih Petani",
                          style: TextStyle(color: hintColor)),
                      dropdownColor:
                          isDarkMode ? Colors.grey[800] : Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: hintColor),
                      style: TextStyle(color: textColor),
                      items: petaniDropdown
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p,
                              child:
                                  Text(p, style: TextStyle(color: textColor)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedPetani = v),
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
                    _input("Lokasi", lokasiCtrl,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        hintColor: hintColor,
                        inputBgColor: inputBgColor),
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
    required bool isDarkMode,
    required Color textColor,
    required Color hintColor,
    required Color inputBgColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          filled: true,
          fillColor: inputBgColor,
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
  final Color textColor;

  const _Col(this.t, this.f, {this.center = false, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: f,
      child: Text(
        t,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ================= TEXT CELL =================
class _Text extends StatelessWidget {
  final String t;
  final int f;
  final Color textColor;

  const _Text(this.t, this.f, {required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: f,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
