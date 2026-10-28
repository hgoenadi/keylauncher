# Riwayat Perubahan

> Jurnal kronologis perubahan project ini. Entri terbaru di paling bawah.

## 1. 2026-10-12 23:31 — Membuat KeyLauncher (launcher ala Keypirinha) di PureBasic


**File:** `keylauncher.pb`, `keylauncher.exe`, `shortcuts.json`

**Cerita:**
Berawal dari permintaan membuat aplikasi peluncur (launcher) bergaya Keypirinha dengan
PureBasic di direktori `C:\Projects\run` yang sebelumnya masih kosong. Ruang lingkup
sengaja dibatasi — tidak meniru seluruh paket Keypirinha, hanya inti pengalamannya:
sebuah jendela pencarian yang bisa dipanggil kapan saja dengan hotkey global, mengindeks
aplikasi dari Start Menu, menampilkan hasil terfilter saat mengetik, lalu menjalankan
item yang dipilih. Kebutuhan yang diminta cukup spesifik: program harus tampil di Task
Manager, punya aktivator global berupa klik-ganda tombol Ctrl, mengindeks aplikasi Start
Menu, menyimpan daftar pintasan tambahan dalam JSON, membuka aplikasi saat nama diklik
atau ditekan Enter, dan membuka Windows Explorer bila item berupa direktori.

Arsitektur yang dipakai adalah aplikasi GUI tunggal PureBasic (window borderless yang
dimulai dalam keadaan tersembunyi). Global activator diimplementasikan dengan low-level
keyboard hook (`SetWindowsHookEx_` dengan `#WH_KEYBOARD_LL`). Hook mencatat waktu setiap
tekanan Ctrl; bila dua tekanan Ctrl terjadi dalam rentang 450 ms, launcher di-toggle
tampil/sembunyi lewat `ShowWindow`/`SetForegroundWindow`. Sebuah penyempurnaan penting
ditambahkan: bila ada tombol lain ditekan di antara dua Ctrl, penghitung waktu di-reset,
sehingga kombinasi seperti Ctrl+C lalu Ctrl+V tidak salah memicu launcher. Karena Windows
tidak mengizinkan hook bertahan dari proses yang mati, hook disimpan di variabel global
dan dilepas (`UnhookWindowsHookEx_`) saat keluar.

Pengindeksan aplikasi dilakukan secara rekursif terhadap folder Start Menu pengguna dan
sistem (`%ProgramData%` dan `%APPDATA%\Microsoft\Windows\Start Menu\Programs`), plus
Desktop, memakai `ExamineDirectory`/`NextDirectoryEntry`. Entri diambil dari berkas
`.lnk`, `.url`, `.exe`, `.bat`, dan `.cmd`, dengan nama file (tanpa ekstensi) sebagai
label. Hasil ditempatkan di array terstruktur lalu diurutkan dengan `SortStructuredArray`.
Selain Start Menu, daftar pintasan kustom dibaca dari `shortcuts.json` di samping exe.
Karena PureBasic tidak punya pustaka JSON bawaan, ditulis parser JSON minimal: sebuah
pemindai string yang mengenali pasangan kunci-nilai `name`/`path` berikut fungsi
`JsonUnescape` (menangani `\\`, `\"`, `\n`, `\r`, `\t`, `\b`, `\f`, `\/`, dan `\uXXXX`).
Berkas dibuat otomatis dengan beberapa contoh bila belum ada, memakai UTF-8 dan melewati
BOM saat dibaca. Parser ini divalidasi dengan program uji terpisah sehingga jalur
Windows ber-backslash dan tanda kutip tetap pulih dengan benar.

Antarmuka launcher terdiri dari `StringGadget` untuk kotak pencarian dan `ListViewGadget`
untuk daftar hasil. Penyaringan berjalan live setiap kali isi kotak berubah (`#PB_EventType_Change`),
dibatasi 200 hasil. Item yang dipilih dijalankan lewat `ShellExecute` (`open`) untuk berkas
biasa maupun `.lnk`, dan lewat `explorer.exe` bila `GetFileAttributes_` menunjukkan
direktori. Tray icon
menggunakan gambar 32×32 yang digambar secara programatik (alpha channel) berupa kaca
pembesar, dengan klik kiri untuk membuka launcher dan klik kanan memunculkan menu
Show/Exit. Sebuah mutex bernama (`CreateMutex_`) dipasang sebagai penjaga single-instance:
bila instance kedua dijalankan, ia langsung keluar.

Tiga masalah utama ditemukan dan diperbaiki sepanjang pengerjaan. Pertama, default JSON
awalnya memakai backslash tunggal (bukan JSON valid) sehingga jalur terpotong saat
di-unescape; diperbaiki menjadi `\\` ganda. Kedua, penambahan ikon tray dan mutex sempat
terkendala proses lama yang menahan lock exe, diselesaikan dengan mematikan proses tersebut.
Ketiga — dan paling penting — tombol Enter tidak menjalankan item meski klik pada daftar
sudah bekerja. Akar masalahnya: `SetWindowCallback` hanya menerima pesan tombol yang
ditujukan ke window utama, padahal saat fokus berada di `StringGadget` (atau `ListView`),
Enter/Esc/panah dikonsumsi oleh kontrol tersebut sehingga callback tak pernah melihatnya.
Solusinya adalah memakai `AddKeyboardShortcut` (accelerator yang diproses sebelum kontrol
yang fokus menerima tombol) untuk memetakan `Return` → Launch, `Escape` → Hide,
`Up`/`Down` → navigasi pilihan, lalu ditangani pada event `#PB_Event_Menu` di loop utama.
Perbaikan ini diverifikasi dengan program uji GUI otomatis (memakai SendKeys/WScript.Shell)
yang membuktikan Enter tetap memicu aksi saat `StringGadget` sedang fokus, menghasilkan
`ENTER [hello]`.

Cara memakai: kompilasi dengan `pbcompiler` ke `keylauncher.exe`, jalankan (ia duduk di
tray), tekan Ctrl dua kali untuk memanggil launcher, ketik untuk memfilter, lalu klik atau
Enter untuk menjalankan. Untuk mengubah/menambah pintasan, edit `shortcuts.json` dengan
format array objek `{ "name": "...", "path": "..." }`.

**Catatan:** manual

## 2. 2026-10-12 23:32 — Memperbesar font antar muka KeyLauncher



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Antarmuka launcher terasa terlalu kecil, jadi ukuran teks dinaikkan. Kotak pencarian
(`StringGadget`) kini memakai font Segoe UI 18 dan daftar hasil (`ListViewGadget`) memakai
Segoe UI 14, dengan `LoadFont` terpisah untuk masing-masing dan diterapkan lewat
`SetGadgetFont`. Tinggi kotak pencarian dinaikkan dari 34 menjadi 40 piksel dan posisi
serta tinggi daftar disesuaikan (mulai di y=64, tinggi `WH-76`) agar tidak terpotong oleh
font yang lebih besar. Perubahan diterapkan pada `keylauncher.pb` dan dibuild ulang bersih
ke `keylauncher.exe` (ExitCode 0), lalu diuji-jalan cepat untuk memastikan launcher tetap
hidup dan responsif.

**Catatan:** manual

## 3. 2026-10-12 23:38 — Memperbaiki fokus launcher saat dipanggil Ctrl ganda



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Keluhan: saat launcher dipanggil dengan Ctrl ganda, fokus ketik sering tetap tertinggal di
aplikasi lama, sehingga huruf yang diketik tidak masuk ke kotak pencarian KeyLauncher.
Akar masalahnya dua lapis. Pertama, `SetForegroundWindow` dari proses latar ditolak oleh
foreground lock Windows, sehingga jendela tampil tetapi tidak menjadi jendela depan aktif.
Kedua, solusi awal sempat memanggil `AttachThreadInput` langsung dari dalam low-level
keyboard hook — ini justru deadlock, karena thread aplikasi depan sedang diblokir menunggu
hook kita selesai, sehingga jendela bahkan tak sempat muncul. Perbaikan akhir: hook hanya
menyetel flag `gWantToggle` (tidak melakukan pekerjaan UI), lalu sebuah `AddWindowTimer`
tiap 100 ms memeriksa flag tersebut di konteks message loop normal dan memanggil
`ShowLauncher`, yang di dalamnya baru menempelkan thread input ke thread foreground
(`AttachThreadInput_`), memanggil `BringWindowToTop_`/`SetForegroundWindow_`, memfokuskan
kotak pencarian, lalu melepas attachment.

Saat diagnosis juga ditemukan bug deteksi yang tak terduga: `ElapsedMilliseconds()` di
versi PureBasic ini mengembalikan nilai 0 pada pemanggilan pertamanya (baru menghitung
sejak panggilan pertama), sehingga penjaga `gLastCtrlMs > 0` membuat Ctrl ganda pertama
gagal terdeteksi. Deteksi diganti memakai `GetTickCount_()` (Windows API, selalu valid)
berpasangan dengan flag `gHaveLastCtrl` alih-alih mengandalkan nilai waktu lebih dari nol.
Sebagai tambahan, `#PB_Shortcut` accelerator dan pemanggilan `ToggleLauncher` langsung dari
hook dibatalkan demi jalur timer yang aman dari deadlock.

Verifikasi dilakukan otomatis lewat injeksi `keybd_event` (Ctrl ganda) di PowerShell
sambil Notepad dijadikan jendela depan: setelah Ctrl ganda, proses yang memegang foreground
berganti menjadi KeyLauncher (sebelumnya Notepad), jendela KeyLauncher terlihat, dan uji
fungsional mengetik "command" lalu Enter sukses meluncurkan proses cmd.exe baru. Seluruh
kode debug sementara (penulisan log) dibersihkan, dan build akhir lolos kompilasi bersih.

**Catatan:** manual

## 4. 2026-10-12 23:41 — Deduplikasi nama pada daftar hasil



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Pengguna menanyakan mengapa kadang muncul baris dengan kata-kata yang sama di daftar hasil.
Investigasi terhadap Start Menu menemukan 228 entri dengan hanya 194 nama unik: aplikasi
yang sama sering memiliki pintasan di beberapa lokasi yang semuanya diindeks — all-users
(`%ProgramData%\...\Start Menu\Programs`), current-user (`%APPDATA%\...\Start Menu\Programs`),
serta Desktop pengguna dan Public. Ditambah entri dari `shortcuts.json`, nama seperti
"Ollama", "Multipass", "Google Chrome", dan "Git Bash" muncul dua sampai tiga kali karena
launcher menampilkan nama file pintasan tanpa membedakan lokasinya.

Perbaikan: fungsi `AddItem` kini melakukan deduplikasi berbasis nama secara case-insensitive
— bila nama sudah ada, entri baru diabaikan (yang pertama menang), sehingga entri Start Menu
yang diindeks lebih dulu diprioritaskan dan baris kembar hilang. Hasilnya ItemCount turun
dari 232 menjadi 197 entri, diverifikasi lewat probe sementara yang menulis jumlah entri ke
berkas. Probe dan seluruh kode diagnostik dibersihkan, lalu build akhir dikompilasi bersih
dan diuji-jalan normal.

**Catatan:** manual

## 5. 2026-10-12 23:43 — Membuka path direktori yang diketik lewat Enter



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Permintaan baru: bila pengguna mengetik nama direktori seperti `c:\` lalu menekan Enter,
launcher harus membuka Windows Explorer menuju direktori tersebut — meskipun direktori itu
tidak ada dalam daftar hasil yang diindeks. Sebelumnya `LaunchSelected` hanya bekerja bila
ada baris terpilih di `ListViewGadget`, sehingga query berupa path yang tidak cocok dengan
entri mana pun tidak melakukan apa-apa.

Perbaikan: `LaunchSelected` kini lebih dulu memeriksa teks kotak pencarian. Teks di-`Trim`
dan diekspansi variabel lingkungannya lewat helper baru `ExpandPath` (memakai
`ExpandEnvironmentStrings_`, sehingga sesuatu seperti `%USERPROFILE%` juga bekerja). Bila
`GetFileAttributes_` menunjukkan path itu ada, launcher langsung ditutup dan dibuka:
direktori dibuka dengan `explorer.exe "<path>"`, sedangkan berkas dibuka lewat
`ShellExecute_` (`open`). Baru bila teks bukan path yang valid, logika jatuh ke perilaku
lama yaitu menjalankan item yang terpilih di daftar.

Verifikasi otomatis: dibuat sebuah direktori uji bernama unik, lalu launcher dipanggil
lewat Ctrl ganda dan path direktori itu diketik kemudian Enter. Hasilnya muncul jendela
Explorer berkelas `CabinetWClass` berjudul sesuai nama direktori uji tersebut. Build bersih
dan direktori uji dibersihkan kembali.

**Catatan:** manual

## 6. 2026-10-12 23:46 — Dukungan `~` sebagai home directory



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Pengguna meminta agar mengetik `~` diartikan sebagai home directory, yaitu
`C:\Users\<nama>`. Helper `ExpandPath` diperluas: bila teks diawali `~`, nilainya diganti
`%USERPROFILE%` (fallback ke `%HOMEDRIVE%%HOMEPATH%` bila kosong). Kasus `~` saja menjadi
seluruh home, sedangkan `~\` atau `~/` diikuti subpath menjadi home + subpath tersebut.
Setelah substitusi `~`, baris tetap melewati `ExpandEnvironmentStrings_` seperti sebelumnya,
sehingga kombinasi seperti `~\Projects` atau `%APPDATA%` tetap berfungsi, lalu dibuka lewat
Explorer (`explorer.exe`) seperti fitur path direktori sebelumnya.

Verifikasi otomatis: launcher dipanggil dengan Ctrl ganda, karakter `~` diketik (lewat
`SendKeys("{~}")` karena `~` adalah karakter khusus SendKeys), lalu Enter. Hasilnya jendela
Explorer berkelas `CabinetWClass` terbuka berjudul `C:\Users\hgoen - File Explorer`, sesuai
home directory pengguna. Build bersih.

**Catatan:** manual

## 7. 2026-10-12 23:54 — Auto-complete path direktori + perbaikan deteksi path



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Permintaan: bila mengetik path direktori yang belum lengkap, launcher sebaiknya
meng-auto-complete ke direktori dengan nama mirip — misalnya `c:\project` menjadi
`c:\projects`. Ditambahkan fungsi `ResolvePath` yang menyusun ulang path komponen demi
komponen: untuk tiap komponen, kalau nama persisnya ada dipakai apa adanya; kalau tidak,
dicari saudara terdekat di direktori induk yang berawalan sama (case-insensitive), dan
hanya diselesaikan bila cocoknya unik — sehingga `c:\proj` menjadi `c:\Projects` tetapi
`c:\pro` yang ambigu (Program Files, ProgramData, Projects) dibiarkan apa adanya. Deteksi
juga mendukung drive (`c:\`), UNC (`\\server\share\`), dan normalisasi garis miring depan.

Auto-complete dijalankan dua tempat: secara live saat mengetik (`TryAutocomplete` pada
event Change, hanya untuk path absolut drive/UNC, memakai penjaga `gAuto` dan menempatkan
kursor di akhir lewat `EM_SETSEL`), dan saat Enter di `LaunchSelected` sebagai jaring
pengaman (`ResolvePath(ExpandPath(teks))`).

Diagnosis juga menemukan bug serius yang selama ini tersembunyi: `GetFileAttributes_`
mengembalikan `4294967295` (yaitu -1 tak bertanda) untuk path yang tidak ada, bukan nilai
`-1` bertanda. Akibatnya pemeriksaan keberadaan path di `IsDirPath` dan `LaunchSelected`
terbalik — setiap teks non-kosong dianggap path yang ada sehingga cabang path selalu
diambil dan peluncuran aplikasi lewat Enter bisa gagal/tertutup tanpa aksi. Diperbaiki
dengan konstanta `#INVALID_ATTR = $FFFFFFFF` dan membandingkan terhadapnya di tiga tempat.
Sebuah penyempurnaan lain: fokus kotak pencarian kini dipastikan ulang oleh timer
(`gRefocus`) sehingga ketikan selalu masuk ke KeyLauncher setelah Ctrl ganda.

Verifikasi: logika `ResolvePath`/`ExpandPath` diuji terpisah (c:\project→c:\Projects,
c:\pro tetap, ~→C:\Users\hgoen, c:/project→c:\Projects). Uji GUI otomatis (keybd_event +
SendKeys) menunjukkan Enter meluncurkan cmd 3/3 kali, dan mengetik `c:\project` lalu Enter
membuka `C:\Projects` serta `~` lalu Enter membuka `C:\Users\hgoen`. Build bersih.

**Catatan:** manual

## 8. 2026-10-12 23:59 — Memperbaiki Backspace vs auto-complete path



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Laporan pengguna: setelah dijalankan, tombol Backspace seolah tidak berfungsi. Penelusuran
memakai pembacaan isi kotak pencarian lintas-proses (via `SendMessage` `WM_GETTEXT`, karena
`GetWindowText` memang selalu mengembalikan kosong untuk isi kontrol milik proses lain)
mengungkap dua masalah pada auto-complete path. Pertama, saat pengguna baru mengetik `c:`,
`ResolvePath` menganggap `c:\` sebagai pelengkap yang sah sehingga kotak otomatis diisi `c:\`;
akibatnya garis miring yang diketik pengguna berikutnya menempel menjadi `c:\\` (backslash
ganda) dan auto-complete lanjutan gagal. Kedua, setiap penghapusan memicu Change yang
kembali mengisi hasil auto-complete (mis. `c:\Projects` di-backspace menjadi `c:\Project`
lalu dilengkapi lagi ke `c:\Projects`), sehingga Backspace tampak tidak bekerja.

Perbaikan: `TryAutocomplete` kini menolak pelengkapan yang hanya menambahkan pemisah
(`extra` setelah menghapus `\` dan `/` harus tidak kosong), dan auto-complete hanya dipicu
ketika panjang teks bertambah (bukan saat menghapus), memakai pelacak `gPrevLen`; urutan
ApplyFilter dipindah ke penangan event agar teks final selalu yang difilter. Verifikasi
lintas-proses menunjukkan `c:\proj` menjadi `c:\Projects`, Backspace mengurangi satu karakter
per tekan tanpa diisi ulang (`c:\Projects`→`c:\Project`→`c:\Proje`), `c:` tetap `c:` tanpa
garis miring liar, dan peluncuran aplikasi lewat Enter tetap jalan (cmd 2/2). Build bersih.

**Catatan:** manual

## 9. 2026-10-13 00:03 — Prefiks `>` untuk membuka cmd di direktori



**File:** `keylauncher.pb`, `keylauncher.exe`

**Cerita:**
Permintaan: jika input berupa direktori, tetap buka Windows Explorer; tetapi jika input
diawali `>`, jalankan cmd.exe yang langsung bekerja di direktori tersebut. `LaunchSelected`
kini mendeteksi prefiks `>` di awal teks: bila ada, teks setelah `>` di-`ResolvePath`/
`ExpandPath`, lalu cwd ditentukan — direktori itu sendiri bila path berupa folder, atau
folder induknya bila berupa berkas, dan `%USERPROFILE%` bila kosong/tak ditemukan.
Selanjutnya `RunProgram("cmd.exe", "", cwd)` dibuka (parameter ketiga RunProgram
menetapkan working directory). Auto-complete ikut mendukung prefiks `>`: `TryAutocomplete`
memisahkan prefiks `>` dari bagian path, melengkapi path-nya, lalu menempelkan kembali
prefiks tersebut.

Saat pengujian juga muncul dan diperbaiki masalah interaksi auto-complete dengan pengetikan
berlanjut: saat mengetik nama penuh (`c:\project`), auto-complete yang terpicu di tengah
(`c:\proj` → `c:\Projects`) membuat sisa karakter (`ect`) menempel setelah hasil sehingga
path rusak. Perbaikannya: setelah melengkapi, bagian yang ditambahkan otomatis di-*select*
lewat `EM_SETSEL` sehingga karakter yang diketik berikutnya menggantikan (menimpa) bagian
lengkapan itu — pola inline-completion standar. Hasilnya mengetik `c:\project` berakhir di
`c:\Project` dan Enter tetap membuka `C:\Projects`, sekaligus Backspace tetap berfungsi.

Verifikasi: mekanisme cwd diuji terpisah (`RunProgram` cmd `cd` menghasilkan `C:\Projects`);
uji GUI otomatis menunjukkan `c:\project`+Enter membuka `C:\Projects - File Explorer`, dan
`>c:\project`+Enter meluncurkan proses cmd (box menunjukkan `>c:\Project`, auto-complete
aktif). Build bersih.

**Catatan:** manual

## 10. 2026-10-13 00:06 — Kompilasi exe dengan optimasi ukuran



**File:** `keylauncher.exe`

**Cerita:**
Permintaan: kompilasi exe dengan optimasi ukuran. Menelusuri opsi `pbcompiler` menunjukkan
tidak ada flag khusus `/SIZE`, tetapi ada dua yang relevan: `/OPTIMIZER` (mengaktifkan
optimizer kode yang membuang kode tak terpakai) dan `/UCRT` (memakai UCRT dinamis sehingga
executable lebih kecil, untuk Windows 10 ke atas). Percobaan membandingkan ukuran:
`/OPTIMIZER` saja tetap ~361.984 byte, sedangkan `/OPTIMIZER /UCRT` turun menjadi ~179.200
byte (sekitar setengah). Varian `/UCRT:` dengan titik dua ditolak compiler (exit 1), dan
`/SSE2` tidak mengubah ukuran sehingga dihindari demi kompatibilitas. Build final memakai
`/OPTIMIZER /UCRT`, dan executable hasilnya diuji-jalan: launcher hidup, tray/hook aktif,
serta uji fungsional Ctrl ganda + ketik "command" + Enter sukses meluncurkan cmd. Tidak ada
debug yang dibiarkan; sumber tidak berubah, hanya cara kompilasi.

**Catatan:** manual

## 11. 2026-10-13 00:09 — Format pintasan diubah dari JSON ke CSV (`shortcuts.cfg`)



**File:** `keylauncher.pb`, `keylauncher.exe`, `shortcuts.cfg` (menggantikan `shortcuts.json`)

**Cerita:**
Permintaan: ubah data pintasan dari `shortcuts.json` menjadi `shortcuts.cfg` dengan format
CSV memakai tanda kutip ganda. Berkas JSON beserta parser JSON buatan sendiri
(`JsonUnescape` dan `LoadShortcuts` gaya JSON) dihapus dan diganti dengan pendekatan CSV.
Ditambahkan `ParseCsvLine` yang mengurai satu baris menjadi dua field (nama, path)
menghormati aturan CSV: field boleh dikelilingi tanda kutip ganda, koma di dalam kutip
dianggap literal, dan kutip ganda di dalam field di-escape dengan menggandakannya (`""` →
`"`); baris tanpa kutip juga tetap didukung. Ditambahkan `CsvQuote` untuk menulis field
(kutip di dalam nilai digandakan). `SaveDefaultShortcuts` kini menulis berkas dengan baris
header `"name","path"` diikuti contoh entri, sementara `LoadShortcuts` membaca baris per
baris, melewati BOM, memangkas spasi, mengabaikan baris header (`name`/`path`) dan baris
kosong, lalu menambahkan entri lewat `AddItem` (deduplikasi nama tetap berlaku). Nama
berkas diubah menjadi `shortcuts.cfg` di samping exe.

Verifikasi: aplikasi dijalankan dan menghasilkan `shortcuts.cfg` (byte awal `"name","path"`,
backslash tunggal benar). Parser CSV diuji terpisah untuk kasus nama dengan spasi, koma di
dalam kutip (`"A,B"`), escape kutip (`"Say ""Hi"""` → `Say "Hi"`), baris tanpa kutip, dan
field path kosong — semuanya benar. Smoke test fungsional (Ctrl ganda → "command" → Enter)
tetap meluncurkan cmd. Build bersih dengan `/OPTIMIZER /UCRT`.

**Catatan:** manual
