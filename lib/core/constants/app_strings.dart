class AppStrings {
  // App
  static const String appName     = 'PERISAI';
  static const String appTagline  = 'Jagain Anak, Tenang di Hati';

  // Role Select
  static const String roleSelectTitle    = 'Hei! Kamu siapa nih?';
  static const String roleParent         = 'Orang Tua';
  static const String roleParentDesc     = 'Pantau si kecil dari sini';
  static const String roleChild          = 'Anak';
  static const String roleChildDesc      = 'Scan QR dari HP orang tua dulu ya';

  // Auth
  static const String login              = 'Masuk';
  static const String register           = 'Daftar Sekarang';
  static const String email              = 'Email kamu';
  static const String password           = 'Password';
  static const String fullName           = 'Nama Lengkap';
  static const String noAccount          = 'Belum punya akun?';
  static const String haveAccount        = 'Sudah punya akun?';
  static const String logout             = 'Keluar';

  // Dashboard
  static const String dashboardTitle     = 'Hai, Selamat Datang!';
  static const String active             = 'AKTIF MELINDUNGI';
  static const String inactive           = 'TIDAK AKTIF';
  static const String noDetection        = 'Semua aman nih!';
  static const String noDetectionDesc    = 'Belum ada aktivitas mencurigakan. '
                                           'Si kecil lagi baik-baik aja';
  static const String todayDetection     = 'Hari Ini';
  static const String weekDetection      = 'Minggu Ini';

  // Detection
  static const String detectionTitle    = 'Detail Deteksi';
  static const String confidence        = 'Seberapa yakin AI-nya?';
  static const String triggeredBy       = 'Ketahuan lewat';
  static const String keywords          = 'Kata yang bikin curiga';
  static const String markAsRead        = 'Oke, sudah kubaca';

  // Triggered by
  static const String ocr              = 'Baca Teks';
  static const String mobilenet        = 'Lihat Gambar';
  static const String trustpositif     = 'Cek URL';
  static const String combined         = 'Ketahuan dari mana-mana';

  // Pairing
  static const String pairingTitle     = 'Hubungkan HP Anak';
  static const String pairingDesc      = 'Minta si kecil scan QR ini '
                                         'dari HP-nya ya!';
  static const String scanQR           = 'Scan QR dulu yuk!';
  static const String scanQRDesc       = 'Arahkan kamera ke QR Code '
                                         'yang ada di HP orang tua';
  static const String pairingSuccess   = 'Yeay, HP berhasil terhubung!';

  // Add Child
  static const String addChild         = 'Tambah Anak';
  static const String childName        = 'Nama si kecil';
  static const String childAge         = 'Umurnya berapa?';
  static const String saveChild        = 'Simpan';

  // Education screen
  static const String educationTitle   = 'Hei, sayang. Tunggu dulu ya';
  static const String educationBody    =
      'Konten yang tadi muncul itu nggak baik buat kamu. '
      'Itu namanya judi online, dan bisa banget ngerusak masa depanmu. '
      '\n\nYuk cerita ke Ayah atau Bunda. '
      'Mereka pasti ngerti kok dan selalu sayang sama kamu.';
  static const String educationButton  = 'Saya Mengerti';

  // Service status
  static const String serviceActive    = 'PERISAI lagi jaga kamu';
  static const String serviceInactive  = 'Eh, PERISAI lagi mati nih';
  static const String serviceInactiveDesc = 'HP anak lagi nggak terlindungi. '
                                            'Cek sekarang ya!';

  // Settings
  static const String settingsTitle    = 'Pengaturan';
  static const String notification     = 'Notifikasi';
  static const String notificationDesc = 'Langsung dikabarin kalau ada yang mencurigakan';
  static const String connectedDevices = 'HP yang Terhubung';

  // Error
  static const String errorGeneral     = 'Aduh, ada yang error nih. Coba lagi?';
  static const String errorNetwork     = 'Kayaknya internetnya lagi ngadat';
  static const String errorLogin       = 'Email atau password-nya salah nih';

  // Auth — tambahkan di bawah yang sudah ada
static const String loginTitle        = 'Hei, selamat\ndatang lagi! 👋';
static const String loginSubtitle     = 'Masuk dulu biar bisa pantau si kecil';
static const String registerTitle     = 'Buat akun\nbaru yuk! 🎉';
static const String registerSubtitle  = 'Daftar sekarang, gratis!';
static const String registerLink      = 'Daftar sekarang';
static const String loginLink         = 'Masuk';

// Validasi
static const String validEmpty        = 'Nggak boleh kosong ya';
static const String validEmailFormat  = 'Format email-nya kurang bener nih';
static const String validPassword     = 'Password minimal 6 karakter';
static const String validName         = 'Nama nggak boleh kosong ya';
static const String validEmail        = 'Email nggak boleh kosong ya';
static const String validPasswordEmpty = 'Password nggak boleh kosong ya';
}