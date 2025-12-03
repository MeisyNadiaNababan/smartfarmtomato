import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminFarmersScreen extends StatefulWidget {
  const AdminFarmersScreen({super.key});

  @override
  State<AdminFarmersScreen> createState() => _AdminFarmersScreenState();
}

class _AdminFarmersScreenState extends State<AdminFarmersScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _filteredFarmers = [];
  bool _isLoading = true;

  // Warna konsisten dengan tema
  final Color _primaryColor = const Color(0xFF006B5D); // Warna utama
  final Color _secondaryColor = const Color(0xFFB8860B); // Warna sekunder
  final Color _backgroundColor = const Color(0xFFF6F7FB); // Background
  final Color _cardColor = Colors.white; // Warna card
  final Color _borderColor = const Color(0xFFE4E7EC); // Warna border
  final Color _textPrimary = const Color(0xFF344054); // Teks primer
  final Color _textSecondary = const Color(0xFF667085); // Teks sekunder
  final Color _addButtonColor = const Color.fromARGB(255, 156, 9, 9); // Warna merah untuk tombol tambah

  @override
  void initState() {
    super.initState();
    _loadFarmers();
    _searchController.addListener(_searchFilter);
  }

  void _loadFarmers() {
    _databaseRef.child('users').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final List<Map<String, dynamic>> farmers = [];

      if (data != null) {
        data.forEach((key, value) {
          // Hanya tampilkan user dengan role 'farmer'
          if (value['role'] == 'farmer') {
            farmers.add({
              'id': key,
              'name': value['name'] ?? value['displayName'] ?? 'Unknown',
              'email': value['email'] ?? '-',
              'status': value['status'] ?? 'active',
              'createdAt': value['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              'lastLogin': value['lastLogin'] ?? DateTime.now().millisecondsSinceEpoch,
              'farmCount': value['farmCount'] ?? 0,
            });
          }
        });
      }

      // Urutkan berdasarkan tanggal pendaftaran (terbaru)
      farmers.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));

      setState(() {
        _farmers = farmers;
        _filteredFarmers = farmers;
        _isLoading = false;
      });
    });
  }

  void _searchFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredFarmers = _farmers.where((f) {
        return f['name'].toLowerCase().contains(query) ||
            f['email'].toLowerCase().contains(query);
      }).toList();
    });
  }

  String _formatDate(int timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return '-';
    }
  }

  void _addFarmer() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tambah Petani Baru',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 16),
                _inputField('Nama Lengkap', nameController),
                const SizedBox(height: 12),
                _inputField('Email', emailController, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _inputField('Password', passwordController, obscureText: true),
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
                        label: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              emailController.text.isEmpty ||
                              passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama, email, dan password harus diisi'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          try {
                            UserCredential userCredential = await FirebaseAuth.instance
                                .createUserWithEmailAndPassword(
                              email: emailController.text,
                              password: passwordController.text,
                            );

                            await _databaseRef
                                .child('users')
                                .child(userCredential.user!.uid)
                                .set({
                              'name': nameController.text,
                              'email': emailController.text,
                              'role': 'farmer',
                              'createdAt': DateTime.now().millisecondsSinceEpoch,
                              'lastLogin': DateTime.now().millisecondsSinceEpoch,
                              'status': 'active',
                              'displayName': nameController.text,
                              'farmCount': 0,
                            });

                            // Tambah activity log
                            await _databaseRef
                                .child('activities')
                                .push()
                                .set({
                              'type': 'farmer_registered',
                              'title': 'Petani Baru Terdaftar',
                              'message': '${nameController.text} telah didaftarkan sebagai petani baru',
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                              'userId': userCredential.user!.uid,
                              'userName': nameController.text,
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Petani berhasil ditambahkan'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            String errorMessage = 'Terjadi kesalahan';
                            if (e.code == 'email-already-in-use') {
                              errorMessage = 'Email sudah digunakan';
                            } else if (e.code == 'weak-password') {
                              errorMessage = 'Password terlalu lemah';
                            } else if (e.code == 'invalid-email') {
                              errorMessage = 'Format email tidak valid';
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $errorMessage'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String hintText = '',
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText.isNotEmpty ? hintText : null,
          filled: true,
          fillColor: const Color(0xFFF2F4F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _editFarmer(Map<String, dynamic> farmer) {
    final TextEditingController nameController = TextEditingController(text: farmer['name']);
    final TextEditingController emailController = TextEditingController(text: farmer['email']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Data Petani',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 16),
                _inputField('Nama Lengkap', nameController),
                const SizedBox(height: 12),
                _inputField('Email', emailController, keyboardType: TextInputType.emailAddress),
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
                        label: const Text('Batal'),
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
                          if (nameController.text.isNotEmpty &&
                              emailController.text.isNotEmpty) {
                            await _databaseRef.child('users').child(farmer['id']).update({
                              'name': nameController.text,
                              'email': emailController.text,
                              'displayName': nameController.text,
                            });

                            // Tambah activity log
                            await _databaseRef
                                .child('activities')
                                .push()
                                .set({
                              'type': 'farmer_updated',
                              'title': 'Data Petani Diperbarui',
                              'message': 'Data ${farmer['name']} telah diperbarui',
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                              'userId': farmer['id'],
                              'userName': nameController.text,
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data petani berhasil diperbarui'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteFarmer(Map<String, dynamic> farmer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Petani'),
        content: Text('Apakah Anda yakin ingin menghapus ${farmer['name']}? Semua data terkait juga akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Tambah activity log sebelum menghapus
                await _databaseRef
                    .child('activities')
                    .push()
                    .set({
                      'type': 'farmer_deleted',
                      'title': 'Petani Dihapus',
                      'message': '${farmer['name']} telah dihapus dari sistem',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                      'userId': farmer['id'],
                      'userName': farmer['name'],
                    });

                // Hapus data dari database
                await _databaseRef.child('users').child(farmer['id']).remove();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Petani berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
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
                    "Manajemen Petani",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Kelola data petani dan akses sistem SmartFarm",
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SEARCH BAR + ADD BUTTON
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Cari nama atau email petani...",
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF98A2B3)),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _addButtonColor, // Warna merah
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: _addFarmer,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text("Tambah Petani"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TABLE/CARD AREA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // TABLE HEADER dengan border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                        border: Border.all(color: _borderColor, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          _Col("Nama Petani", 3),
                          _Col("Email", 3),
                          _Col("Tanggal Daftar", 2),
                          _Col("Status", 1),
                          _Col("Aksi", 2, center: true),
                        ],
                      ),
                    ),

                    // DATA LIST dengan border dan kotak persegi panjang untuk setiap item
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: _primaryColor),
                            )
                          : _filteredFarmers.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: _cardColor,
                                    border: Border.all(color: _borderColor, width: 1),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 3,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Belum ada petani terdaftar",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Silakan tambah petani baru",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: _cardColor,
                                    border: Border.all(color: _borderColor, width: 1),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 3,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    itemCount: _filteredFarmers.length,
                                    itemBuilder: (context, index) {
                                      final farmer = _filteredFarmers[index];
                                      final isActive = farmer['status'] == 'active';
                                      final joinDate = _formatDate(farmer['createdAt']);

                                      // Kotak persegi panjang untuk setiap item
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8), // Border radius lebih kecil untuk bentuk persegi panjang
                                          border: Border.all(
                                            color: _borderColor,
                                            width: 1,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              _Text(farmer['name'], 3, bold: true),
                                              _Text(farmer['email'], 3),
                                              _Text(joinDate, 2),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: isActive ? Colors.green : Colors.red,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isActive ? 'Aktif' : 'Nonaktif',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isActive ? Colors.green : Colors.red,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _PillIcon(
                                                      Icons.edit,
                                                      Colors.blue,
                                                      () => _editFarmer(farmer),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    _PillIcon(
                                                      Icons.delete,
                                                      Colors.red,
                                                      () => _deleteFarmer(farmer),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET UNTUK KOLOM HEADER
class _Col extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;

  const _Col(this.text, this.flex, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF667085),
        ),
      ),
    );
  }
}

// WIDGET UNTUK TEKS DALAM CELL
class _Text extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;

  const _Text(this.text, this.flex, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
          color: const Color(0xFF344054),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// WIDGET UNTUK ICON BUTTON
class _PillIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PillIcon(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
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