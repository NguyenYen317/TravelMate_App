# ✈️ TravelMate App

Ứng dụng du lịch thông minh bằng Flutter, tập trung vào 4 nhóm chính:
- 🔎 Khám phá địa điểm
- 🧳 Lập kế hoạch chuyến đi (thủ công + AI)
- 💸 Quản lý chi phí + OCR hóa đơn
- 🌐 Nhật ký cộng đồng + Chat Bot AI

---

## 🚀 Tính năng đã hoàn thành (theo code hiện tại)

### 🔐 1. Xác thực người dùng
- Đăng nhập / đăng ký tài khoản.
- Đăng nhập bằng Google.
- `AuthGate` tự điều hướng theo trạng thái đăng nhập.

### 🧭 2. Điều hướng chính trong app
Bottom navigation hiện có **5 tab**:
1. 🏠 Trang chủ
2. 🧭 Khám phá
3. 🧳 Chuyến đi
4. 🌐 Nhật ký cộng đồng
5. 👤 Cá nhân

Ngoài ra có **🤖 bong bóng Chat Bot nổi** trên toàn app (kéo thả được).

### 🏠 3. Trang chủ
- Header chào người dùng.
- Thanh tìm kiếm nhanh.
- Card **The Planner (AI)**:
  - Nhập prompt tự nhiên (ví dụ: `Đà Nẵng 3 ngày`).
  - AI tạo lịch trình theo ngày.
  - Có `Xem thêm / Thu gọn`.
  - Có nút `Tạo chuyến đi từ AI` để đẩy thẳng sang tab Chuyến đi.

### 🧭 4. Khám phá địa điểm
Gồm 2 tab con:
- **Khám phá**: tìm kiếm địa điểm, lọc danh mục, xem chi tiết.
- **AI gợi ý**:
  - Sinh bài gợi ý theo dữ liệu chuyến đi hiện có.
  - Loại gợi ý: địa điểm đẹp, món ăn, văn hóa địa phương.
  - Có thể like/comment cục bộ, lưu yêu thích.
  - Có nút `Thêm vào chuyến đi` theo ngày cụ thể.

### 🧳 5. Quản lý chuyến đi
- Tạo chuyến đi với:
  - Tên chuyến đi
  - Khoảng ngày
  - **Giờ bắt đầu / giờ kết thúc**
  - Chọn nhanh địa điểm từ danh sách yêu thích
- Quản lý lịch trình theo ngày:
  - Thêm/sửa/xóa địa điểm
  - Gán giờ cho từng hoạt động
  - Kéo-thả đổi thứ tự (reorder)
- Mở nhanh sang màn quản lý chi phí của chuyến đi.

### 💸 6. Quản lý chi phí + quét hóa đơn OCR
- Thêm/sửa/xóa chi phí thủ công.
- Lọc theo loại và ngày.
- Biểu đồ tròn thống kê theo danh mục.
- Quét hóa đơn bằng camera/thư viện:
  - OCR text
  - Tách tổng tiền
  - Tự điền form chi phí

### 🌐 7. Nhật ký cộng đồng
- Feed bài viết theo thời gian (có load thêm).
- Đăng bài text hoặc text + ảnh.
- Sửa/xóa bài viết của chính mình.
- Like/unlike bài viết.
- Comment realtime (bottom sheet).
- Bộ lọc: `Tất cả bài đăng` / `Bài của tôi`.

### 🔔 8. Smart Assistant Notifications
- Poll nhắc lịch trình theo thời gian.
- Hiện banner nổi trong app.
- Tự đóng sau 5 giây hoặc đóng thủ công.

### 🤖 9. Chat Bot AI (bong bóng nổi)
- Bong bóng nổi toàn app, kéo-thả vị trí.
- Nhấn để mở `BottomSheet` tiêu đề `Chat Bot`.
- Input tự focus, bàn phím đẩy layout đúng.
- Luồng chuẩn ổn định:
  - `UI -> Provider -> Service -> API -> Provider -> UI`

---

## 🧠 Kiến trúc kỹ thuật

- UI không gọi API trực tiếp.
- `Provider` quản lý state/loading/error.
- `AIPlannerService` chịu trách nhiệm gọi AI provider.
- `SocialService` xử lý Firestore + upload ảnh.

---

## 🛠️ Công nghệ sử dụng

- Flutter (Dart)
- Provider
- Firebase:
  - `firebase_core`
  - `firebase_auth`
  - `cloud_firestore`
  - `firebase_storage`
- AI/API:
  - Gemini API
  - Ollama API
  - HTTP
- Ảnh/OCR:
  - `image_picker`
  - `google_mlkit_text_recognition`
- Bản đồ/Vị trí:
  - `flutter_map`
  - `geolocator`
  - `latlong2`
- Khác:
  - `flutter_local_notifications`
  - `timezone`
  - `shared_preferences`
  - `hive`

---

## ⚙️ Cấu hình AI bằng `--dart-define`

### ✅ Gemini
- `AI_PROVIDER=gemini`
- `GEMINI_API_KEY=...`
- `GEMINI_MODEL=gemini-2.0-flash` (mặc định)

### ✅ Ollama
- `AI_PROVIDER=ollama`
- `OLLAMA_BASE_URL=http://...:11434`
- `OLLAMA_MODEL=llama3.2:3b` (hoặc model bạn có)

---

## ▶️ Cách chạy dự án

### 1) Cài dependencies
```bash
flutter pub get
```

### 2) Chạy trên Android Emulator + Ollama (Windows)
```bash
flutter emulators --launch Pixel_4
flutter run -d emulator-5554 --dart-define=AI_PROVIDER=ollama --dart-define=OLLAMA_BASE_URL=http://10.0.2.2:11434 --dart-define=OLLAMA_MODEL=llama3.2:3b
```

### 3) Chạy trên máy thật Android + Ollama (cùng LAN)
```bash
flutter run -d <DEVICE_ID> --dart-define=AI_PROVIDER=ollama --dart-define=OLLAMA_BASE_URL=http://<PC_LAN_IP>:11434 --dart-define=OLLAMA_MODEL=llama3.2:3b
```

### 4) Chạy với Gemini
```bash
flutter run -d <DEVICE_ID> --dart-define=AI_PROVIDER=gemini --dart-define=GEMINI_API_KEY=<YOUR_KEY> --dart-define=GEMINI_MODEL=gemini-2.0-flash
```

---

## ☁️ Firebase / Cloud cần cấu hình

### Firestore
- Tạo Firestore Database.
- Collection social chính: `social_posts`.

### Upload ảnh bài viết
Code hiện tại upload ảnh qua Cloudinary bằng:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_UPLOAD_PRESET`

Nếu thiếu Cloudinary, app vẫn cho đăng bài **text-only**.

---

## 📁 Cấu trúc thư mục (dễ nhìn)

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── constants/
│   ├── providers/
│   ├── services/
│   ├── theme/
│   └── utils/
├── data/
│   ├── datasources/
│   └── models/
├── features/
│   ├── ai/
│   │   ├── models/
│   │   ├── ai_provider.dart
│   │   └── ai_planner_service.dart
│   ├── auth/
│   │   ├── provider/
│   │   ├── screens/
│   │   └── auth_service.dart
│   ├── community/
│   │   └── screens/
│   ├── expense/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   ├── home/
│   │   ├── screens/
│   │   └── widgets/
│   ├── map/
│   │   ├── screens/
│   │   └── map_service.dart
│   ├── notification/
│   │   ├── widgets/
│   │   └── notification_service.dart
│   ├── profile/
│   │   └── screens/
│   ├── search/
│   │   ├── provider/
│   │   ├── screens/
│   │   └── search_service.dart
│   ├── social/
│   │   ├── models/
│   │   ├── providers/
│   │   └── services/
│   ├── sync/
│   │   └── sync_service.dart
│   └── trip/
│       ├── models/
│       ├── providers/
│       ├── screens/
│       └── trip_service.dart
└── routes/
    └── app_routes.dart
```

---

## 📌 Ghi chú quan trọng
- Không commit API key thật lên GitHub.
- Nên dùng UTF-8 cho toàn bộ file Dart/Markdown để tránh lỗi font tiếng Việt.
- Nếu gặp lỗi kết nối Ollama trên Android emulator, dùng `10.0.2.2:11434`.

---

## 👥 Nhóm phát triển
TravelMate team.
