import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminNotificationService { 
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  static const Color _primaryColor = Color(0xFF006B5D);
  static const Color _secondaryColor = Color(0xFFB8860B);
  static const Color _tertiaryColor = Color(0xFF558B2F);
  static const Color _blueColor = Color(0xFF1A237E);
  static const Color _greenColor = Color(0xFF2E7D32);
  static const Color _accentColor = Color(0xFFB71C1C);

  // ================== NOTIFIKASI PETANI BARU ==================
  static Future<void> notifyNewFarmerRegistration(
    String userName,
    String userEmail,
    String userId,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _databaseRef.child('admin_notifications').push();

      await newRef.set({
        'title': '👨‍🌾 Petani Baru Mendaftar',
        'message': '$userName ($userEmail) telah bergabung sebagai petani baru',
        'timestamp': timestamp,
        'isRead': false,
        'type': 'info',
        'source': 'registration',
        'action': 'new_farmer',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'category': 'user_registration',
        'priority': 'medium',
      });

      print('✅ Notifikasi: Petani baru berhasil didaftarkan - $userName');
    } catch (e) {
      print('❌ Error notifikasi petani baru: $e');
    }
  }

  // ================== NOTIFIKASI PERMINTAAN RESET PASSWORD ==================
  static Future<void> notifyPasswordResetRequest(
    String userName,
    String userEmail,
    String userId,
    String requestId,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _databaseRef.child('admin_notifications').push();

      await newRef.set({
        'title': '🔐 Permintaan Reset Password',
        'message': '$userName ($userEmail) mengajukan permintaan reset password',
        'timestamp': timestamp,
        'isRead': false,
        'type': 'warning',
        'source': 'password_reset',
        'action': 'password_reset_request',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'requestId': requestId,
        'category': 'password_reset',
        'priority': 'high',
      });

      print('✅ Notifikasi: Permintaan reset password - $userName');
    } catch (e) {
      print('❌ Error notifikasi reset password: $e');
    }
  }

  // ================== NOTIFIKASI RESET PASSWORD DISETUJUI ==================
  static Future<void> notifyPasswordResetApproved(
    String userName,
    String userEmail,
    String userId,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _databaseRef.child('admin_notifications').push();

      await newRef.set({
        'title': '✅ Reset Password Disetujui',
        'message': 'Password untuk $userName ($userEmail) telah direset',
        'timestamp': timestamp,
        'isRead': false,
        'type': 'success',
        'source': 'password_reset',
        'action': 'password_reset_approved',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'category': 'password_reset',
        'priority': 'info',
      });

      print('✅ Notifikasi: Reset password disetujui - $userName');
    } catch (e) {
      print('❌ Error notifikasi reset password disetujui: $e');
    }
  }

  // ================== NOTIFIKASI RESET PASSWORD DITOLAK ==================
  static Future<void> notifyPasswordResetRejected(
    String userName,
    String userEmail,
    String userId,
    String reason,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = _databaseRef.child('admin_notifications').push();

      await newRef.set({
        'title': '❌ Reset Password Ditolak',
        'message': 'Permintaan reset password untuk $userName ditolak: $reason',
        'timestamp': timestamp,
        'isRead': false,
        'type': 'error',
        'source': 'password_reset',
        'action': 'password_reset_rejected',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'reason': reason,
        'category': 'password_reset',
        'priority': 'info',
      });

      print('✅ Notifikasi: Reset password ditolak - $userName');
    } catch (e) {
      print('❌ Error notifikasi reset password ditolak: $e');
    }
  }

  // ================== MANAJEMEN NOTIFIKASI ==================
  
  // Stream untuk mendapatkan semua notifikasi admin (hanya yang terkait petani dan reset password)
  static Stream<List<AdminNotificationItem>> getNotifications() {
    return _databaseRef
        .child('admin_notifications')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<AdminNotificationItem> notifications = [];
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        data.forEach((key, value) {
          final source = value['source']?.toString() ?? 'system';
          final category = value['category']?.toString();
          
          // FILTER: Hanya ambil notifikasi yang terkait dengan pendaftaran petani atau reset password
          final isUserRegistration = category == 'user_registration' || source == 'registration';
          final isPasswordReset = category == 'password_reset' || source == 'password_reset';
          
          if (isUserRegistration || isPasswordReset) {
            notifications.add(AdminNotificationItem(
              id: key.toString(),
              title: value['title']?.toString() ?? 'Notifikasi',
              message: value['message']?.toString() ?? '',
              source: source,
              isRead: value['isRead'] == true,
              timestamp: value['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
              type: value['type']?.toString() ?? 'info',
              action: value['action']?.toString(),
              userId: value['userId']?.toString(),
              userName: value['userName']?.toString(),
              userEmail: value['userEmail']?.toString(),
              requestId: value['requestId']?.toString(),
              reason: value['reason']?.toString(),
              category: category,
              priority: value['priority']?.toString() ?? 'medium',
            ));
          }
          // Jika bukan kategori yang diinginkan, kita skip notifikasi ini
        });
      }

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return notifications;
    });
  }

  // Stream untuk mendapatkan notifikasi belum dibaca (hanya yang terkait petani dan reset password)
  static Stream<int> getUnreadCount() {
    return _databaseRef
        .child('admin_notifications')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      int count = 0;

      if (data != null) {
        data.forEach((key, value) {
          final isRead = value['isRead'] == true;
          final source = value['source']?.toString() ?? 'system';
          final category = value['category']?.toString();
          
          // FILTER: Hanya hitung notifikasi yang terkait dengan pendaftaran petani atau reset password
          final isUserRegistration = category == 'user_registration' || source == 'registration';
          final isPasswordReset = category == 'password_reset' || source == 'password_reset';
          
          if (!isRead && (isUserRegistration || isPasswordReset)) {
            count++;
          }
        });
      }

      return count;
    });
  }

  // Method untuk menandai notifikasi sebagai dibaca
  static Future<void> markAsRead(String notificationId) async {
    await _databaseRef
        .child('admin_notifications/$notificationId/isRead')
        .set(true);
  }

  // Method untuk menandai semua notifikasi sebagai dibaca (hanya yang terkait petani dan reset password)
  static Future<void> markAllAsRead() async {
    final notifications = await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var key in data.keys) {
        final value = data[key];
        final source = value?['source']?.toString() ?? 'system';
        final category = value?['category']?.toString();
        
        // FILTER: Hanya tandai yang terkait dengan pendaftaran petani atau reset password
        final isUserRegistration = category == 'user_registration' || source == 'registration';
        final isPasswordReset = category == 'password_reset' || source == 'password_reset';
        
        if (isUserRegistration || isPasswordReset) {
          await _databaseRef.child('admin_notifications/$key/isRead').set(true);
        }
      }
    }
  }

  // Method untuk menghapus notifikasi yang tidak terkait petani atau reset password
  static Future<void> cleanUpUnrelatedNotifications() async {
    final notifications = await _databaseRef.child('admin_notifications').once();
    final data = notifications.snapshot.value as Map<dynamic, dynamic>?;

    if (data != null) {
      for (var key in data.keys) {
        final value = data[key];
        final source = value?['source']?.toString() ?? 'system';
        final category = value?['category']?.toString();
        
        // FILTER: Hanya simpan yang terkait dengan pendaftaran petani atau reset password
        final isUserRegistration = category == 'user_registration' || source == 'registration';
        final isPasswordReset = category == 'password_reset' || source == 'password_reset';
        
        // Hapus jika bukan kategori yang diinginkan
        if (!isUserRegistration && !isPasswordReset) {
          await _databaseRef.child('admin_notifications/$key').remove();
          print('🗑️ Menghapus notifikasi tidak terkait: $key');
        }
      }
    }
  }
}

class AdminNotificationItem {
  final String id;
  final String title;
  final String message;
  final String source;
  final bool isRead;
  final int timestamp;
  final String type;
  final String? action;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? requestId;
  final String? reason;
  final String? category;
  final String? priority;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.source,
    required this.isRead,
    required this.timestamp,
    required this.type,
    this.action,
    this.userId,
    this.userName,
    this.userEmail,
    this.requestId,
    this.reason,
    this.category,
    this.priority,
  });

  DateTime get dateTime {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes}m yang lalu';
    if (difference.inDays < 1) return '${difference.inHours}j yang lalu';
    if (difference.inDays < 7) return '${difference.inDays}h yang lalu';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} minggu yang lalu';

    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Color get typeColor {
    switch (type) {
      case 'warning':
        return const Color(0xFFB8860B);
      case 'error':
        return const Color(0xFFB71C1C);
      case 'success':
        return const Color(0xFF2E7D32);
      case 'info':
      default:
        return const Color(0xFF006B5D);
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get sourceLabel {
    switch (source) {
      case 'registration':
        return 'Pendaftaran';
      case 'password_reset':
        return 'Reset Password';
      case 'system':
        return 'Sistem';
      default:
        return source;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Helper method untuk memeriksa apakah notifikasi terkait petani
  bool get isFarmerRelated {
    return category == 'user_registration' || source == 'registration';
  }

  // Helper method untuk memeriksa apakah notifikasi terkait reset password
  bool get isPasswordResetRelated {
    return category == 'password_reset' || source == 'password_reset';
  }
}