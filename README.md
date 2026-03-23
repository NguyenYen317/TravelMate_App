# TRAVELMATE_APP
MỘT ỨNG DỤNG DU LỊCH THÔNG MINH XÂY DỰNG BẰNG FLUTTER

📌 Introduction
- TravelMate là một ứng dụng du lịch thông minh được phát triển bằng Flutter, giúp người dùng khám phá địa điểm, lập kế hoạch chuyến đi, quản lý chi phí và chia sẻ trải nghiệm du lịch.
- Ứng dụng hướng đến trải nghiệm đa nền tảng (Android & iOS), giao diện thân thiện, dễ sử dụng và tích hợp các công nghệ hiện đại như bản đồ, AI và lưu trữ dữ liệu.

🎯 Objectives
- Xây dựng ứng dụng du lịch tích hợp nhiều chức năng trong một nền tảng
- Hỗ trợ người dùng:
- Tìm kiếm và khám phá địa điểm
- Lập kế hoạch chuyến đi
- Quản lý chi phí
- Kết nối cộng đồng du lịch
- Ứng dụng AI để gợi ý lịch trình thông minh

🛠️ Technologies Used
🔹 Main Technologies
Flutter (Dart)
SharedPreferences (Local Storage)
Firebase (Authentication, Firestore, Storage)

🔹 Map & Location
Google Maps Flutter
Geolocator
Google Places API
Google Directions API

🔹 AI Integration
OpenAI API / Gemini API (for itinerary suggestion)

🔹 Other
HTTP (API calls)
Local Database (Hive / SQLite)
Flutter Local Notifications

🚀 Features
🔐 1. Authentication
Register with username & password (local storage)
Login / Logout
Google Sign-In

🔍 2. Place Search & Discovery
Search places by name (autocomplete)
Filter:
Restaurants
Hotels
Tourist attractions
View place details:
Name, image, address
Rating, opening hours
Add / remove favorite places

🗺️ 3. Map & Navigation
Display Google Map
Detect current location (GPS)
Show user location
Show place markers
Directions from current location
Nearby places suggestion

🧳 4. Trip Planning
Create trip (name, start date, end date)
Add places to itinerary
Organize places by day
View:
Timeline
Calendar
Edit / delete places
Drag & drop to reorder

💰 5. Expense Management
Add expenses:
Amount
Category (food, hotel, transport)
Calculate total cost
Filter by:
Date
Category

🤖 6. AI Itinerary Suggestion
Input natural language:
Example: “Travel to Da Nang for 3 days”
Automatically generate:
List of places
Daily schedule

🌐 7. Social Travel Network
Create posts:
Image, content, location
Interactions:
Like
Comment
Infinite scrolling feed

🔔 8. Notifications
Trip reminders
Check-in reminders
Social interaction notifications

☁️ 9. Data Synchronization
Cloud storage
Multi-device sync
Data backup

📷 10. Bill Scanning (Advanced)
Scan receipts using camera
Extract text (OCR)
Automatically add to expenses

👥 Team Structure (Suggested)
Member	Responsibility
A	Authentication + App Base
B	Search + Place
C	Map + Navigation
D	Trip + Expense
E	AI + Social + Notification + Sync

🔄 Application Flow
1. Login / Register
2. Search places or view map
3. Create trip
4. Add places to itinerary
5. Manage expenses
6. Share experiences
   
📂 Project Structure (Example)
lib/
│── models/
│── services/
│── screens/
│── widgets/
│── providers/
│── utils/
│── main.dart

⚙️ Setup Instructions
1. Clone project
git clone https://github.com/NguyenYen317/TRAVELMATE_APP.git
cd travelmate

3. Install dependencies
flutter pub get

5. Configure API Keys
Google Maps API Key
Places API Key
Firebase config
AI API Key

7. Run app
flutter run

⚠️ Notes
Cần bật billing cho Google Maps API
Firebase cần cấu hình cho Android/iOS
Không commit API keys lên GitHub

📈 Future Improvements
Offline mode
Recommendation system nâng cao
Voice search
Real-time chat
AI cá nhân hóa lịch trình

📌 Conclusion

TravelMate là một hệ thống ứng dụng du lịch thông minh tích hợp nhiều chức năng từ cơ bản đến nâng cao. Việc sử dụng Flutter giúp đảm bảo hiệu năng, khả năng mở rộng và trải nghiệm người dùng tốt trên nhiều nền tảng.

⭐ License

This project is for educational purposes.
