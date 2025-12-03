// ignore_for_file: undefined_class, unused_local_variable
// lib/screens/admin/farmers/admin_farmers.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            });
          }
        });
      }

      // Urutkan berdasarkan nama
      farmers.sort((a, b) => a['name'].compareTo(b['name']));

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

  void _addFarmer() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Petani Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty) {
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
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Petani berhasil ditambahkan')),
                  );
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'Terjadi kesalahan';
                  if (e.code == 'email-already-in-use') {
                    errorMessage = 'Email sudah digunakan';
                  } else if (e.code == 'weak-password') {
                    errorMessage = 'Password terlalu lemah';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $errorMessage')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _editFarmer(Map<String, dynamic> farmer) {
    final TextEditingController nameController =
        TextEditingController(text: farmer['name']);
    final TextEditingController emailController =
        TextEditingController(text: farmer['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Petani'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty) {
                await _databaseRef.child('users').child(farmer['id']).update({
                  'name': nameController.text,
                  'email': emailController.text,
                  'displayName': nameController.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Petani berhasil diupdate')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteFarmer(Map<String, dynamic> farmer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Petani'),
        content: Text('Apakah Anda yakin ingin menghapus ${farmer['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Hapus user dari Firebase Auth (jika ingin)
                // await FirebaseAuth.instance.currentUser?.delete();
                
                // Hapus data dari database
                await _databaseRef.child('users').child(farmer['id']).remove();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Petani berhasil dihapus')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //------------------------------------------------------------------
            // HEADER SIMPLE
            //------------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            size: 22,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Management Petani",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Kelola data petani dan akses sistem SmartFarm",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            //------------------------------------------------------------------
            // SEARCH + TAMBAH PETANI
            //------------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // SEARCH BAR
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Cari nama atau email petani...",
                          icon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ADD BUTTON
                  ElevatedButton(
                    onPressed: _addFarmer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC4B31),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "Tambah",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            //------------------------------------------------------------------
            // TABLE HEADER
            //------------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "No",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Nama",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Email",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Aksi",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //------------------------------------------------------------------
            // DATA TABLE LIST
            //------------------------------------------------------------------
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6E8036),
                      ),
                    )
                  : _filteredFarmers.isEmpty
                      ? Center(
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
                                "Silakan tambah petani atau tunggu pendaftaran",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredFarmers.length,
                          separatorBuilder: (context, index) => Container(
                            height: 1,
                            color: Colors.grey.shade100,
                          ),
                          itemBuilder: (context, index) {
                            final farmer = _filteredFarmers[index];

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          farmer['name'],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      farmer['email'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        // EDIT BUTTON WITH GREEN BOX
                                        GestureDetector(
                                          onTap: () => _editFarmer(farmer),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade100,
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // DELETE BUTTON WITH RED BOX
                                        GestureDetector(
                                          onTap: () => _deleteFarmer(farmer),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.red.shade100,
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}