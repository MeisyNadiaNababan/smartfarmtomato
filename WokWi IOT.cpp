#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "DHT.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <time.h>

// --- WiFi Configuration ---
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""

// --- Firebase Configuration ---
#define FIREBASE_HOST "https://smartfarmtomato-default-rtdb.asia-southeast1.firebasedatabase.app"

// --- NTP Configuration ---
const char* ntpServer1 = "pool.ntp.org";
const char* ntpServer2 = "time.nist.gov";
const char* ntpServer3 = "time.google.com";
const long  gmtOffset_sec = 7 * 3600; // GMT+7 (WIB)
const int   daylightOffset_sec = 0;

// --- Pin & Sensor ---
#define DHTPIN 15
#define DHTTYPE DHT22
#define SOIL_PIN 34
#define LDR_PIN 35
#define RELAY_PIN 4
#define SERVO_PIN 23

DHT dht(DHTPIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 20, 4);
Servo pompaServo;

unsigned long previousMillis = 0;
const long interval = 5000; // 5 detik
unsigned long lastNotificationCheck = 0;
const long NOTIFICATION_INTERVAL = 10000; // Cek notifikasi setiap 10 detik

// --- Variabel Penyiraman Tomat ---
unsigned long lastWateringTime = 0;
const long WATERING_DURATION = 15000; // 15 DETIK
bool wateringInProgress = false;
unsigned long wateringStartTime = 0;

// --- Kategori Umur Tanaman Tomat ---
int plantAgeDays = 1;
unsigned long lastAgeUpdate = 0;
const long DAY_DURATION = 24 * 60 * 60 * 1000; // 1 hari dalam ms

// Variabel untuk data terbaru
float currentTemperature = 0;
float currentHumidity = 0;
float currentSoilPercent = 0;
float currentBrightnessPercent = 0;
String currentSoilCategory = "";
String currentAirHumStatus = "";
String currentBrightnessCategory = "";
String currentTempStatus = "";
String currentTime = "";
bool currentPompaStatus = false;
String currentOperatingMode = "AUTO";

// --- Variabel Notifikasi ---
String lastNotification = "";
unsigned long notificationStartTime = 0;
bool showingNotification = false;
const long NOTIFICATION_DISPLAY_TIME = 5000; // Tampilkan notifikasi 5 detik

// --- Variabel Manajemen Data ---
String lastDataHash = ""; // Untuk mendeteksi perubahan data
bool timeInitialized = false;
String currentDataKey = ""; // Key untuk data saat ini di Firebase

// --- Custom Characters (Icons) ---
byte tomato[8] = {
  B00000, B01110, B11111, B11111, B11111, B01110, B00000, B00000
};

byte fire[8] = {
  B00000, B00100, B01110, B01010, B10001, B10001, B11011, B01110
};

byte thermometer[8] = {
  B00100, B01010, B01010, B01010, B01010, B10001, B10001, B01110
};

byte waterDrop[8] = {
  B00100, B00100, B01010, B01010, B10001, B10001, B10001, B01110
};

byte soil[8] = {
  B11111, B10101, B11111, B10101, B11111, B10101, B11111, B00000
};

byte sun[8] = {
  B10101, B01110, B11011, B01110, B11011, B01110, B11011, B10101
};

byte wifiIcon[8] = {
  B00000, B01110, B10001, B00000, B00100, B01010, B00000, B00100
};

byte alertIcon[8] = {
  B00000, B00100, B01110, B01110, B01110, B11111, B11111, B00100
};

// Fungsi min custom untuk menghindari error
int customMin(int a, int b) {
  return (a < b) ? a : b;
}

void printCenter(int row, String text) {
  int col = (20 - text.length()) / 2;
  lcd.setCursor(col, row);
  lcd.print(text);
}

// --- PERBAIKAN: Fungsi Waktu yang lebih sederhana ---
bool syncNTPTime() {
  Serial.println("🕒 Mencoba sinkronisasi waktu NTP...");
  
  // Reset time configuration
  configTime(0, 0, "", ""); // Reset config
  delay(1000);
  
  // Coba multiple NTP servers
  const char* ntpServers[] = {ntpServer1, ntpServer2, ntpServer3};
  int numServers = sizeof(ntpServers) / sizeof(ntpServers[0]);
  
  for (int i = 0; i < numServers; i++) {
    Serial.println("Mencoba server: " + String(ntpServers[i]));
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServers[i]);
    
    // Tunggu untuk mendapatkan waktu
    struct tm timeinfo;
    int timeout = 0;
    while (!getLocalTime(&timeinfo) && timeout < 15) {
      Serial.print(".");
      delay(1000);
      timeout++;
    }
    
    if (timeout < 15) {
      // Verifikasi tahun (harus >= 2020)
      int currentYear = timeinfo.tm_year + 1900;
      Serial.println("✅ Waktu tersinkronisasi dari " + String(ntpServers[i]));
      Serial.println("📅 Tahun: " + String(currentYear));
      
      if (currentYear >= 2020) {
        Serial.println("✅ Tahun valid!");
        timeInitialized = true;
        return true;
      } else {
        Serial.println("❌ Tahun tidak valid: " + String(currentYear));
      }
    } else {
      Serial.println("❌ Gagal sinkronisasi dari " + String(ntpServers[i]));
    }
    delay(1000);
  }
  
  // Jika semua server gagal, set waktu ke tahun 2024
  Serial.println("⚠️ Mengatur waktu manual ke tahun 2024...");
  setManualTime2024();
  timeInitialized = true;
  return true;
}

// PERBAIKAN: Set waktu ke 2024 (bukan 2025)
void setManualTime2024() {
  struct tm timeinfo;
  timeinfo.tm_year = 124;  // 2024 - 1900
  timeinfo.tm_mon = 11;    // Desember (0-based)
  timeinfo.tm_mday = 1;    // Tanggal 1
  timeinfo.tm_hour = 13;   // Jam 13
  timeinfo.tm_min = 0;     // Menit 0
  timeinfo.tm_sec = 0;     // Detik 0
  timeinfo.tm_isdst = 0;   // No daylight saving
  
  time_t epochTime = mktime(&timeinfo);
  struct timeval tv;
  tv.tv_sec = epochTime;
  tv.tv_usec = 0;
  
  if (settimeofday(&tv, NULL) == 0) {
    Serial.println("✅ Waktu manual 2024-12-01 13:00:00 diatur");
  } else {
    Serial.println("❌ Gagal mengatur waktu manual");
  }
}

String getFormattedDateTime() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    return "Tunggu sinkronisasi...";
  }
  
  char timeString[64];
  strftime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(timeString);
}

String getFormattedDate() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    return "Sinkronisasi...";
  }
  
  char dateString[32];
  strftime(dateString, sizeof(dateString), "%Y-%m-%d", &timeinfo);
  return String(dateString);
}

String getFormattedTime() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    return "--:--:--";
  }
  
  char timeString[32];
  strftime(timeString, sizeof(timeString), "%H:%M:%S", &timeinfo);
  return String(timeString);
}

// PERBAIKAN: Fungsi timestamp yang menghasilkan POSITIF
long getTimestampForFirebase() {
  if (!timeInitialized) {
    Serial.println("⚠️ Waktu belum diinisialisasi, menggunakan millis");
    return millis() + 1700000000000L; // Base timestamp positif
  }
  
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    Serial.println("⚠️ Gagal mendapatkan waktu lokal, menggunakan millis");
    return millis() + 1700000000000L;
  }
  
  // Verifikasi tahun
  int currentYear = timeinfo.tm_year + 1900;
  if (currentYear < 2020) {
    Serial.println("⚠️ Tahun tidak valid: " + String(currentYear) + ", menggunakan fallback");
    return millis() + 1700000000000L;
  }
  
  time_t epochTime = mktime(&timeinfo);
  long timestamp = epochTime * 1000L; // Convert to milliseconds
  
  // Pastikan timestamp positif
  if (timestamp <= 0) {
    timestamp = millis() + 1700000000000L;
  }
  
  Serial.println("🕒 Timestamp: " + String(timestamp) + " (" + getFormattedDateTime() + ")");
  return timestamp;
}

// --- Fungsi Umur Tanaman ---
String getPlantStage() {
  if (plantAgeDays <= 14) return "BIBIT";
  else if (plantAgeDays <= 35) return "VEGETATIF";
  else if (plantAgeDays <= 50) return "BERBUNGA";
  else return "PEMBUAHAN";
}

int getSoilThreshold() {
  if (plantAgeDays <= 14) return 30;   // Bibit
  else if (plantAgeDays <= 35) return 40; // Vegetatif
  else if (plantAgeDays <= 50) return 50; // Berbunga
  else return 60;                       // Pembuahan
}

String getSoilCategory(float soilPercent) {
  if (soilPercent < 30.0) return "SANGAT KERING";
  else if (soilPercent < 50.0) return "KERING";
  else if (soilPercent <= 70.0) return "LEMBAB";
  else return "BASAH";
}

String getBrightnessCategory(float brightnessPercent) {
  if (brightnessPercent < 20.0) return "GELAP";
  else if (brightnessPercent < 50.0) return "REMANG";
  else if (brightnessPercent < 80.0) return "TERANG";
  else return "SANGAT TERANG";
}

String getBrightnessStatus(float brightnessPercent) {
  if (brightnessPercent < 20.0) return "CAHAYA RENDAH";
  else if (brightnessPercent < 50.0) return "CAHAYA SEDANG";
  else if (brightnessPercent < 80.0) return "CAHAYA BAIK";
  else return "CAHAYA TINGGI";
}

void updatePlantAge() {
  unsigned long currentMillis = millis();
  if (currentMillis - lastAgeUpdate >= DAY_DURATION) {
    plantAgeDays++;
    lastAgeUpdate = currentMillis;
    Serial.println("🎉 HARI KE-" + String(plantAgeDays) + ": " + getPlantStage());
  }
}

// --- Fungsi Waktu Penyiraman ---
bool isWateringTime() {
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    return false;
  }
  
  int currentHour = timeinfo.tm_hour;
  return (currentHour >= 6 && currentHour <= 10) || (currentHour >= 16 && currentHour <= 18);
}

String readFirebaseString(String path) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = FIREBASE_HOST;
    url += path;

    http.begin(url);
    int httpCode = http.GET();

    if (httpCode > 0) {
      String payload = http.getString();
      http.end();
      payload.replace("\"", "");
      return payload;
    }
    http.end();
  }
  return "";
}

// --- PERBAIKAN: Fungsi Notifikasi dengan timestamp positif ---
bool sendNotificationToFirebase(String title, String message, String type = "info") {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    
    // Gunakan timestamp POSITIF
    long timestamp = getTimestampForFirebase();
    
    // Buat key yang unik
    String notificationKey = "notif_" + String(timestamp) + "_" + String(random(1000, 9999));
    
    String notificationData = "{";
    notificationData += "\"title\":\"" + title + "\",";
    notificationData += "\"message\":\"" + message + "\",";
    notificationData += "\"type\":\"" + type + "\",";
    notificationData += "\"timestamp\":" + String(timestamp) + ",";
    notificationData += "\"isRead\":false,";
    notificationData += "\"createdAt\":\"" + getFormattedDateTime() + "\"";
    notificationData += "}";

    String notificationUrl = FIREBASE_HOST;
    notificationUrl += "/notifications/";
    notificationUrl += notificationKey;
    notificationUrl += ".json";
    
    Serial.println("📤 Mengirim notifikasi...");
    Serial.println("🗂️ Key: " + notificationKey);
    Serial.println("🕒 Waktu: " + getFormattedDateTime());
    Serial.println("📅 Timestamp: " + String(timestamp));
    
    http.begin(notificationUrl);
    http.addHeader("Content-Type", "application/json");
    int httpResponseCode = http.PUT(notificationData);
    
    if (httpResponseCode > 0) {
      Serial.println("✅ Notifikasi berhasil! Response: " + String(httpResponseCode));
      http.end();
      return true;
    } else {
      Serial.println("❌ Gagal mengirim notifikasi! Error: " + String(httpResponseCode));
      http.end();
      return false;
    }
  } else {
    Serial.println("❌ WiFi tidak terhubung");
    return false;
  }
}

void checkAndGenerateNotifications(float temperature, float humidity, float soilPercent, 
                                  float brightnessPercent, bool isDay) {
  // Generate notifikasi berdasarkan kondisi
  String notificationTitle = "";
  String notificationMessage = "";
  String notificationType = "info";
  
  // Notifikasi suhu
  if (temperature > 32.0) {
    notificationTitle = "🔥 Suhu Terlalu Tinggi";
    notificationMessage = "Suhu: " + String(temperature, 1) + "°C - Risiko heat stress pada tanaman tomat!";
    notificationType = "warning";
  } else if (temperature < 10.0) {
    notificationTitle = "❄️ Suhu Terlalu Rendah";
    notificationMessage = "Suhu: " + String(temperature, 1) + "°C - Pertumbuhan tanaman lambat!";
    notificationType = "warning";
  }
  
  // Notifikasi kelembaban udara
  else if (humidity > 80.0) {
    notificationTitle = "💨 Kelembaban Tinggi";
    notificationMessage = "Kelembaban: " + String(humidity, 0) + "% - Risiko jamur dan penyakit!";
    notificationType = "warning";
  } else if (humidity < 50.0) {
    notificationTitle = "🏜️ Kelembaban Rendah";
    notificationMessage = "Kelembaban: " + String(humidity, 0) + "% - Tanaman mengalami stres!";
    notificationType = "warning";
  }
  
  // Notifikasi tanah
  else if (soilPercent < getSoilThreshold()) {
    notificationTitle = "💧 Tanah Kering";
    notificationMessage = "Kelembaban tanah: " + String(soilPercent, 0) + "% - Perlu penyiraman! Threshold: " + String(getSoilThreshold()) + "%";
    notificationType = "warning";
  } else if (soilPercent > 80.0) {
    notificationTitle = "💦 Tanah Terlalu Basah";
    notificationMessage = "Kelembaban tanah: " + String(soilPercent, 0) + "% - Risiko busuk akar!";
    notificationType = "warning";
  }
  
  // Notifikasi cahaya
  else if (brightnessPercent < 20.0 && isDay) {
    notificationTitle = "🌑 Cahaya Kurang";
    notificationMessage = "Cahaya: " + String(brightnessPercent, 0) + "% - Photosintesis rendah pada siang hari";
    notificationType = "info";
  } else if (brightnessPercent > 90.0) {
    notificationTitle = "☀️ Cahaya Berlebih";
    notificationMessage = "Cahaya: " + String(brightnessPercent, 0) + "% - Risiko daun terbakar";
    notificationType = "warning";
  }
  
  // Notifikasi penyiraman
  else if (currentPompaStatus && !wateringInProgress) {
    notificationTitle = "🚰 Penyiraman Aktif";
    notificationMessage = "Pompa menyala untuk menyiram tanaman tomat. Kelembaban tanah: " + String(soilPercent, 1) + "%";
    notificationType = "info";
  }
  
  // Notifikasi tahap pertumbuhan
  else if (plantAgeDays == 15 || plantAgeDays == 36 || plantAgeDays == 51) {
    notificationTitle = "🌱 Tahap Pertumbuhan Baru";
    notificationMessage = "Tanaman masuk tahap: " + getPlantStage() + " - Penyesuaian perawatan diperlukan";
    notificationType = "info";
  }
  
  // Kirim notifikasi jika ada yang baru dan berbeda dari sebelumnya
  if (notificationTitle != "" && notificationMessage != "") {
    String currentNotification = notificationTitle + "|" + notificationMessage;
    if (currentNotification != lastNotification) {
      bool success = sendNotificationToFirebase(notificationTitle, notificationMessage, notificationType);
      if (success) {
        lastNotification = currentNotification;
        Serial.println("📢 NOTIFIKASI: " + notificationTitle + " - " + notificationMessage);
      }
    }
  }
}

void checkFirebaseNotifications() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = FIREBASE_HOST;
    url += "/notifications.json?orderBy=\"timestamp\"&limitToLast=5";

    http.begin(url);
    int httpCode = http.GET();

    if (httpCode > 0) {
      String payload = http.getString();
      if (payload != "null") {
        DynamicJsonDocument doc(2048);
        DeserializationError error = deserializeJson(doc, payload);
        
        if (!error) {
          for (JsonPair kv : doc.as<JsonObject>()) {
            String title = kv.value()["title"] | "Notifikasi";
            String message = kv.value()["message"] | "";
            bool isRead = kv.value()["isRead"] | false;
            
            if (!isRead && message != "" && message != lastNotification) {
              Serial.println("📢 NOTIFIKASI FIREBASE: " + title + " - " + message);
              lastNotification = message;
              
              // Mark as read
              String notificationKey = kv.key().c_str();
              String readUrl = FIREBASE_HOST;
              readUrl += "/notifications/";
              readUrl += notificationKey;
              readUrl += "/isRead.json";
              
              HTTPClient http2;
              http2.begin(readUrl);
              http2.addHeader("Content-Type", "application/json");
              http2.PUT("true");
              http2.end();
              
              Serial.println("✅ Notifikasi Firebase dibaca: " + title);
            }
          }
        }
      }
    }
    http.end();
  }
}

// --- Fungsi Penyiraman Cerdas ---
void smartTomatoWatering(float soilPercent) {
  unsigned long currentMillis = millis();
  int soilThreshold = getSoilThreshold();
  
  if (wateringInProgress) {
    if (currentMillis - wateringStartTime >= WATERING_DURATION) {
      digitalWrite(RELAY_PIN, LOW);
      pompaServo.write(0);
      wateringInProgress = false;
      lastWateringTime = currentMillis;
      currentPompaStatus = false;
      sendNotificationToFirebase(
        "✅ Penyiraman Selesai", 
        "Durasi 15 detik selesai\nKelembaban tanah: " + String(soilPercent, 1) + "%\nTahap: " + getPlantStage(),
        "success"
      );
    }
  } else {
    bool shouldWater = false;
    
    if (currentOperatingMode == "AUTO") {
      if (soilPercent < soilThreshold && isWateringTime()) {
        shouldWater = true;
      }
      
      if (shouldWater) {
        digitalWrite(RELAY_PIN, HIGH);
        pompaServo.write(90);
        wateringInProgress = true;
        wateringStartTime = currentMillis;
        currentPompaStatus = true;
        sendNotificationToFirebase(
          "🚰 Penyiraman Dimulai", 
          "Tanah kering: " + String(soilPercent, 0) + "%\nThreshold: " + String(soilThreshold) + "%\nTahap: " + getPlantStage(),
          "info"
        );
      }
    }
  }
}

// --- Fungsi untuk membuat hash data ---
String createDataHash(float temp, float hum, float soil, float bright, String pumpStatus) {
  // Buat hash sederhana untuk mendeteksi perubahan data
  String hash = String(temp, 1) + "_" + 
                String(hum, 1) + "_" + 
                String(soil, 1) + "_" + 
                String(bright, 1) + "_" + 
                pumpStatus;
  return hash;
}

// --- PERBAIKAN: Fungsi untuk memindahkan data lama ke history ---
void moveOldDataToHistory() {
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("🔄 Mengecek data lama untuk dipindahkan ke history...");
    
    // Baca data saat ini dari current_data
    HTTPClient http;
    String currentUrl = FIREBASE_HOST;
    currentUrl += "/current_data.json";
    
    http.begin(currentUrl);
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String payload = http.getString();
      http.end();
      
      if (payload != "null" && payload.length() > 10) {
        Serial.println("📥 Data lama ditemukan, memindahkan ke history...");
        
        // Parse data untuk mendapatkan datetime
        DynamicJsonDocument doc(1024);
        DeserializationError error = deserializeJson(doc, payload);
        
        if (!error) {
          // Gunakan millis + random untuk key yang positif dan unik
          String historyKey = "data_" + String(millis()) + "_" + String(random(10000, 99999));
          
          // Simpan data lama ke history_data
          String historyUrl = FIREBASE_HOST;
          historyUrl += "/history_data/";
          historyUrl += historyKey;
          historyUrl += ".json";
          
          http.begin(historyUrl);
          http.addHeader("Content-Type", "application/json");
          int historyCode = http.PUT(payload);
          
          if (historyCode > 0) {
            Serial.println("✅ Data lama dipindahkan ke history_data dengan key: " + historyKey);
          } else {
            Serial.println("❌ Gagal memindahkan data ke history: " + String(historyCode));
          }
          http.end();
        }
      } else {
        Serial.println("ℹ️ Tidak ada data di current_data (mungkin pertama kali)");
      }
    } else {
      Serial.println("❌ Gagal membaca current_data: " + String(httpCode));
    }
  }
}

// --- PERBAIKAN PENTING: Fungsi kirim data yang benar ---
void sendToFirebase(float temperature, float humidity, float soilPercent,
                    float brightnessPercent, String soilCategory,
                    String airHumStatus, String brightnessCategory,
                    String tempStatus, bool isDay) {

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;

    String currentDateTime = getFormattedDateTime();
    long timestamp = getTimestampForFirebase();
    
    // Buat hash data saat ini
    String currentHash = createDataHash(temperature, humidity, soilPercent, 
                                       brightnessPercent, 
                                       currentPompaStatus ? "ON" : "OFF");
    
    // Cek apakah data berubah
    if (currentHash == lastDataHash) {
      Serial.println("ℹ️ Data tidak berubah, skip update");
      return;
    }
    
    // Jika data berubah, pindahkan data lama ke history
    moveOldDataToHistory();
    
    lastDataHash = currentHash;
    
    // Buat data JSON lengkap
    String jsonData = "{";
    jsonData += "\"suhu\":" + String(temperature, 1) + ",";
    jsonData += "\"kelembaban_udara\":" + String(humidity, 1) + ",";
    jsonData += "\"kelembaban_tanah\":" + String(soilPercent, 1) + ",";
    jsonData += "\"kecerahan\":" + String(brightnessPercent, 1) + ",";
    jsonData += "\"kategori_tanah\":\"" + soilCategory + "\",";
    jsonData += "\"status_kelembaban\":\"" + airHumStatus + "\",";
    jsonData += "\"kategori_cahaya\":\"" + brightnessCategory + "\",";
    jsonData += "\"status_suhu\":\"" + tempStatus + "\",";
    jsonData += "\"waktu\":\"" + String(isDay ? "Siang" : "Malam") + "\",";
    jsonData += "\"status_pompa\":\"" + String(currentPompaStatus ? "ON" : "OFF") + "\",";
    jsonData += "\"mode_operasi\":\"" + currentOperatingMode + "\",";
    jsonData += "\"umur_tanaman\":" + String(plantAgeDays) + ",";
    jsonData += "\"tahapan_tanaman\":\"" + getPlantStage() + "\",";
    jsonData += "\"tanggal\":\"" + getFormattedDate() + "\",";
    jsonData += "\"jam\":\"" + getFormattedTime() + "\",";
    jsonData += "\"datetime\":\"" + currentDateTime + "\",";
    jsonData += "\"timestamp\":" + String(timestamp);
    jsonData += "}";

    // PERBAIKAN: Simpan data baru ke history_data dengan key POSITIF
    String historyKey = "data_" + String(timestamp) + "_" + String(random(1000, 9999));
    String historyUrl = FIREBASE_HOST;
    historyUrl += "/history_data/";
    historyUrl += historyKey;
    historyUrl += ".json";
    
    http.begin(historyUrl);
    http.addHeader("Content-Type", "application/json");
    int historyCode = http.PUT(jsonData);
    
    if (historyCode > 0) {
      Serial.println("✅ Data baru disimpan ke history_data: " + historyKey);
    } else {
      Serial.println("❌ Gagal menyimpan ke history_data: " + String(historyCode));
    }
    http.end();

    // PERBAIKAN: Update current_data
    String currentUrl = FIREBASE_HOST;
    currentUrl += "/current_data.json";
    http.begin(currentUrl);
    http.addHeader("Content-Type", "application/json");
    int currentCode = http.PUT(jsonData);
    
    if (currentCode > 0) {
      Serial.println("✅ Current data diperbarui");
    } else {
      Serial.println("❌ Gagal memperbarui current data: " + String(currentCode));
    }
    http.end();

    Serial.println("📊 Data dikirim - " + currentDateTime);
    Serial.println("🆔 Timestamp: " + String(timestamp));
    Serial.println("🔑 History Key: " + historyKey);
  }
}

void checkPompaControl(float soilPercent) {
  if (WiFi.status() == WL_CONNECTED) {
    String operatingMode = readFirebaseString("/control/operating_mode.json");
    
    if (operatingMode == "" || operatingMode == "null") {
      operatingMode = "AUTO";
    }
    
    currentOperatingMode = operatingMode;

    if (operatingMode == "AUTO") {
      smartTomatoWatering(soilPercent);
    } else {
      String pompaStatus = readFirebaseString("/control/pompa_status.json");
      
      if (pompaStatus == "" || pompaStatus == "null") {
        pompaStatus = "OFF";
      }

      if (pompaStatus == "ON" && !currentPompaStatus) {
        digitalWrite(RELAY_PIN, HIGH);
        pompaServo.write(90);
        currentPompaStatus = true;
        wateringInProgress = true;
        wateringStartTime = millis();
        sendNotificationToFirebase("🔧 Pompa Manual", "Pompa diaktifkan via Firebase\nMode: MANUAL", "info");
      } else if (pompaStatus == "OFF" && currentPompaStatus) {
        digitalWrite(RELAY_PIN, LOW);
        pompaServo.write(0);
        currentPompaStatus = false;
        wateringInProgress = false;
        sendNotificationToFirebase("🔧 Pompa Manual", "Pompa dimatikan via Firebase\nMode: MANUAL", "info");
      }
      
      if (wateringInProgress && (millis() - wateringStartTime >= WATERING_DURATION)) {
        digitalWrite(RELAY_PIN, LOW);
        pompaServo.write(0);
        currentPompaStatus = false;
        wateringInProgress = false;
        sendNotificationToFirebase("⏰ Safety Timer", "Pompa auto-off setelah 15 detik\nMode: MANUAL Safety", "info");
      }
    }
  } else {
    if (soilPercent < getSoilThreshold() && isWateringTime()) {
      digitalWrite(RELAY_PIN, HIGH);
      pompaServo.write(90);
      currentPompaStatus = true;
    } else {
      digitalWrite(RELAY_PIN, LOW);
      pompaServo.write(0);
      currentPompaStatus = false;
    }
  }
}

// --- HALAMAN LCD: Tampilkan Data Sensor Saja ---
void displaySensorData() {
  lcd.clear();
  
  // Baris 1: Suhu
  lcd.setCursor(0, 0);
  lcd.write(byte(2)); // Icon thermometer
  lcd.print(" Suhu: ");
  lcd.print(currentTemperature, 1);
  lcd.print((char)223);
  lcd.print("C");
  
  // Baris 2: Kelembaban Udara
  lcd.setCursor(0, 1);
  lcd.write(byte(3)); // Icon water drop
  lcd.print(" Udara: ");
  lcd.print(currentHumidity, 0);
  lcd.print("%");
  
  // Baris 3: Kelembaban Tanah
  lcd.setCursor(0, 2);
  lcd.write(byte(4)); // Icon soil
  lcd.print(" Tanah: ");
  lcd.print(currentSoilPercent, 0);
  lcd.print("%");
  
  // Baris 4: Kecerahan Cahaya
  lcd.setCursor(0, 3);
  lcd.write(byte(5)); // Icon sun
  lcd.print(" Cahaya: ");
  lcd.print(currentBrightnessPercent, 0);
  lcd.print("%");
}

void setup() {
  Serial.begin(115200);
  dht.begin();
  lcd.init();
  lcd.backlight();
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);

  // Setup servo sebagai simulasi pompa
  pompaServo.setPeriodHertz(50);
  pompaServo.attach(SERVO_PIN, 500, 2400);
  pompaServo.write(0);

  // Create custom characters
  lcd.createChar(0, tomato);
  lcd.createChar(1, fire);
  lcd.createChar(2, thermometer);
  lcd.createChar(3, waterDrop);
  lcd.createChar(4, soil);
  lcd.createChar(5, sun);
  lcd.createChar(6, wifiIcon);
  lcd.createChar(7, alertIcon);

  // --- Tampilan awal ---
  lcd.clear();
  printCenter(1, "System Starting");

  for (int i = 0; i < 3; i++) {
    lcd.setCursor(16 + i, 1);
    lcd.print(".");
    delay(500);
  }

  lcd.clear();

  // Header border tomat
  lcd.setCursor(0, 0);
  for (int i = 0; i < 20; i++) {
    lcd.write(byte(0));
  }

  printCenter(1, "SmartFarm");
  printCenter(2, "Tomato System");

  lcd.setCursor(0, 3);
  for (int i = 0; i < 20; i++) {
    lcd.write(byte(0));
  }

  delay(2000);
  lcd.clear();

  // --- Connect WiFi ---
  lcd.clear();
  printCenter(1, "Connecting to WiFi");  
  lcd.setCursor(9, 2);                  
  lcd.write(byte(6));

  Serial.print("Connecting to WiFi");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(1000);
    Serial.print(".");
    lcd.setCursor(10 + (attempts % 10), 2);
    lcd.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());

    // --- PERBAIKAN: Sinkronisasi waktu ---
    lcd.clear();
    printCenter(1, "Syncing Time...");
    
    bool timeSynced = syncNTPTime();
    
    if (timeSynced) {
      lcd.clear();
      printCenter(1, "Time Synced!");
      printCenter(2, getFormattedDate());
      printCenter(3, getFormattedTime());
      Serial.println("✅ Waktu berhasil disinkronisasi");
      Serial.println("📅 Tanggal: " + getFormattedDate());
      Serial.println("🕒 Jam: " + getFormattedTime());
    } else {
      lcd.clear();
      printCenter(1, "Time Sync Failed");
      printCenter(2, "Using Manual Time");
      Serial.println("⚠️ Gagal sinkronisasi, menggunakan waktu manual");
    }
    
    delay(3000);
  } else {
    Serial.println("WiFi Failed!");
    lcd.clear();
    printCenter(1, "WiFi Failed");
    delay(2000);
  }

  // Firebase Ready
  lcd.clear();
  for (int i = 0; i < 3; i++) {
    lcd.clear();
    printCenter(1, "Firebase Ready");

    lcd.setCursor(6, 2);
    lcd.write(byte(1));
    lcd.setCursor(8, 2);
    lcd.write(byte(1));
    lcd.setCursor(10, 2);
    lcd.write(byte(1));
    lcd.setCursor(12, 2);
    lcd.write(byte(1));
    delay(500);

    lcd.clear();
    printCenter(1, "Firebase Ready");
    lcd.setCursor(7, 2);
    lcd.write(byte(1));
    lcd.setCursor(9, 2);
    lcd.write(byte(1));
    lcd.setCursor(11, 2);
    lcd.write(byte(1));
    lcd.setCursor(13, 2);
    lcd.write(byte(1));
    delay(100);
  }

  Serial.println("Firebase Initialized!");
  Serial.println("=== SISTEM BUDIDAYA TOMAT ===");
  Serial.println("Waktu Sistem: " + getFormattedDateTime());
  Serial.println("Waktu Penyiraman: 06.00-10.00 & 16.00-18.00");
  Serial.println("Durasi: 15 detik per penyiraman");
  Serial.println("==============================");
  
  // Inisialisasi waktu tanam
  lastAgeUpdate = millis();
  plantAgeDays = 1;
  
  // Notifikasi sistem mulai
  bool notificationSent = sendNotificationToFirebase(
    "🚀 Sistem Dimulai", 
    "Smart Farm Tomato aktif\n" + getFormattedDateTime() + "\nTahap: " + getPlantStage() + " (Hari " + String(plantAgeDays) + ")",
    "info"
  );
  if (notificationSent) {
    Serial.println("✅ Notifikasi sistem berhasil dikirim!");
  } else {
    Serial.println("❌ Gagal mengirim notifikasi sistem!");
  }
  
  delay(3000);
  previousMillis = millis() - interval;
  lastNotificationCheck = millis();
  
  // Tampilkan data sensor pertama kali
  displaySensorData();
}

void loop() {
  unsigned long currentMillis = millis();

  updatePlantAge();

  if (currentMillis - lastNotificationCheck >= NOTIFICATION_INTERVAL) {
    checkFirebaseNotifications();
    lastNotificationCheck = currentMillis;
  }

  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    // Generate simulated sensor data
    float temperature = random(220, 320) / 10.0;
    float humidity = random(450, 850) / 10.0;
    int soil = random(2800, 3500);
    int ldr = random(500, 4000);

    float soilPercent = constrain(map(soil, 0, 4095, 100, 0), 0, 100);
    float brightnessPercent = (ldr / 4095.0) * 100.0;
    brightnessPercent = constrain(brightnessPercent, 0, 100);

    currentSoilCategory = getSoilCategory(soilPercent);

    if (humidity < 50.0) currentAirHumStatus = "RH Rendah";
    else if (humidity <= 70.0) currentAirHumStatus = "RH Ideal";
    else if (humidity < 80.0) currentAirHumStatus = "RH Tinggi";
    else currentAirHumStatus = "Risiko Jamur";

    currentBrightnessCategory = getBrightnessCategory(brightnessPercent);

    bool isDay = (brightnessPercent > 25.0);

    if (temperature > 32.0)
      currentTempStatus = "Suhu > max toleransi (panas)";
    else if (temperature < 10.0)
      currentTempStatus = "Suhu < min toleransi (dingin)";
    else {
      if (isDay) {
        currentTempStatus = (temperature >= 20.0 && temperature <= 28.0) ? "Suhu Siang Ideal" : "Suhu Siang Tidak Ideal";
      } else {
        currentTempStatus = (temperature >= 18.0 && temperature <= 22.0) ? "Suhu Malam Ideal" : "Suhu Malam Tidak Ideal";
      }
    }

    currentTemperature = temperature;
    currentHumidity = humidity;
    currentSoilPercent = soilPercent;
    currentBrightnessPercent = brightnessPercent;
    currentTime = isDay ? "Siang" : "Malam";

    // Output serial
    Serial.println();
    Serial.println("=== DATA BUDIDAYA TOMAT ===");
    Serial.print("Waktu: "); Serial.println(getFormattedDateTime());
    Serial.print("Tahapan: "); Serial.print(getPlantStage());
    Serial.print(" (Hari ke-"); Serial.print(plantAgeDays); Serial.println(")");
    Serial.print("Suhu: "); Serial.print(temperature, 1); Serial.print("°C - "); Serial.println(currentTempStatus);
    Serial.print("Kelembaban Udara: "); Serial.print(humidity, 1); Serial.print("% - "); Serial.println(currentAirHumStatus);
    Serial.print("Kelembaban Tanah: "); Serial.print(soilPercent, 1); Serial.print("% - "); Serial.println(currentSoilCategory);
    Serial.print("Kecerahan Cahaya: "); Serial.print(brightnessPercent, 1); Serial.print("% - "); Serial.println(getBrightnessStatus(brightnessPercent));
    Serial.println("================================");

    checkPompaControl(soilPercent);
    checkAndGenerateNotifications(temperature, humidity, soilPercent, brightnessPercent, isDay);
    sendToFirebase(temperature, humidity, soilPercent, brightnessPercent,
                   currentSoilCategory, currentAirHumStatus, currentBrightnessCategory,
                   currentTempStatus, isDay);
    
    // Update LCD dengan data sensor
    displaySensorData();
  }
  
  if (wateringInProgress) {
    smartTomatoWatering(currentSoilPercent);
  }
}