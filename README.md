smartfarmtomato
🌱 SmartFarm Tomato – IoT Tomato Plant Monitoring System
SmartFarm Tomato adalah sistem monitoring dan kontrol tanaman tomat berbasis IoT yang memungkinkan petani memantau kondisi lingkungan tanaman secara real-time melalui aplikasi mobile.

✨ Fitur Utama
- 📊 Dashboard Real-time - Monitoring suhu, kelembaban tanah, kelembaban udara, dan intensitas cahaya
- ⚙️ Kontrol Otomatis - Sistem penyiraman otomatis berdasarkan kelembaban tanah
- 🎮 Kontrol Manual - Kontrol manual pompa dan lampu melalui aplikasi
- 📈 Riwayat Data - Penyimpanan dan visualisasi data historis
- 🔔 Notifikasi - Pemberitahuan kondisi kritis
- 👤 Multi-role - Akses berbeda untuk Admin dan User

📌 Live Demo & Resources
GitHub Repository: https://github.com/MeisyNadiaNababan/smartfarmtomato.git

Firebase Database: https://console.firebase.google.com/project/smartfarmtomato/database/smartfarmtomato-default-rtdb/data/~2F

IoT Simulation: Wokwi with ESP32 https://wokwi.com/projects/448933422674658305

🚀 Panduan Instalasi Lengkap
Prerequisites
- Sebelum memulai, pastikan Anda telah menginstal:
- Flutter SDK 3.0+
- Android Studio / VS Code dengan ekstensi Flutter
- Git
- Akun Firebase

### Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MeisyNadiaNababan/smartfarmtomato.git
   cd smartfarmtomato
2. **Install dependencies Flutter:**
   ```bash
    flutter pub get
3. **Setup Firebase:**
- Buka Firebase Console
- Buat project baru atau gunakan project "smartfarmtomato"
- Tambahkan aplikasi Android dengan package name: com.smartfarm.tomato
- Download file google-services.json
- Letakkan file di folder: android/app/google-services.json
4. **Jalankan aplikasi:**
   ```bash
    # Untuk Android device/emulator
    flutter run

    # Atau untuk device tertentu
    flutter run -d <device_id>

    # Untuk melihat daftar device
    flutter devices

📊 Cara Menggunakan Aplikasi
1. Registrasi/Login:
- Buka aplikasi SmartFarm Tomato
- Registrasi akun baru atau login dengan akun yang ada
- Admin dapat mengelola user dan pengaturan sistem

2. Monitoring Dashboard:
- Data sensor ditampilkan secara real-time

3. Kontrol Sistem:
- Mode Otomatis: Sistem bekerja berdasarkan threshold
- Mode Manual: Kontrol langsung pompa dan lampu
- Ubah mode di halaman Control

4. Riwayat Data:
- Akses halaman History untuk melihat data historis