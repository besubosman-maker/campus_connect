# CampusConnect 🎓📱

**CampusConnect** is a full-featured Flutter mobile application designed as a student-to-student marketplace with built-in real-time chat and a verified seller reputation system. Built with Flutter, Dart, Firebase, and Provider state management.

---

## 🚀 Key Features

1. **Student Authentication & Profiles (`/screens/auth`)**
   - Email and password registration with client-side campus domain validation.
   - Profile management with customizable avatar photo upload and display name.
   - Password reset via email.

2. **Marketplace Browsing & Search (`/screens/home`)**
   - Grid view with pull-to-refresh (`RefreshIndicator`).
   - Category filtering chips (Textbooks, Electronics, Furniture, Clothing, School Supplies, Housing, Services, Other).
   - Fast keyword search via Firestore `searchKeywords` array.
   - Infinite pagination with `limit(20)` and `startAfterDocument`.

3. **Listing Details & Management (`/screens/listing`)**
   - Multi-image carousel with page indicator dots.
   - Seller reputation summary card with live average rating and review counts.
   - Direct "Chat with Seller" and "Rate Seller" action buttons.
   - Multi-image picker with camera and gallery support, pre-compressing images to `maxWidth: 1024` and `quality: 80%`.
   - "My Listings" dashboard to mark items as sold, edit listings, or delete items and their cloud storage assets.

4. **1-on-1 Real-Time Chat (`/screens/chat`)**
   - Deterministic chat ID creation (`sorted(uidA + "_" + uidB)`), guaranteeing a single thread between any two campus peers.
   - Real-time message streaming using Firestore `snapshots()`.
   - Unread message counters and read receipt status checkmarks.
   - Built-in public meeting safety recommendations for student exchanges.

5. **Verified Seller Reputation System (`/screens/rating`)**
   - 5-star interactive rating with written comments.
   - Anti-fraud rule: Rating a seller requires an existing chat history.
   - Atomic Firestore transactions updating the seller's aggregate score and total review counter.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: Flutter (Latest Stable) + Dart
- **State Management**: `provider` (Clean separation of UI, Domain Services, and App State)
- **Firebase SDKs**:
  - `firebase_core` (Initialization)
  - `firebase_auth` (User identity & session management)
  - `cloud_firestore` (NoSQL Real-time database)
  - `firebase_storage` (Image hosting for listings & profile pictures)
- **Utilities**:
  - `cached_network_image` (Fast image caching and placeholder rendering)
  - `image_picker` (Camera & gallery multi-image capture with compression)
  - `intl` (Currency and relative timestamp formatting)
  - `uuid` (Unique file identifiers)

### Folder Hierarchy

```
campus_connect/
├── firestore.rules          # Firestore security rules
├── storage.rules            # Firebase Storage security rules
├── firebase.json            # Firebase CLI deployment config
├── lib/
│   ├── constants/           # AppConstants (categories, theme colors)
│   ├── firebase_options.dart# Firebase platform configuration
│   ├── main.dart            # MultiProvider entry point & Material 3 theme
│   ├── models/              # UserModel, ListingModel, ChatModel, MessageModel, RatingModel
│   ├── providers/           # AuthProvider, ListingProvider
│   ├── screens/
│   │   ├── auth/            # AuthGate, LoginScreen, RegisterScreen
│   │   ├── chat/            # ChatListScreen, ChatScreen
│   │   ├── home/            # HomeScreen (Browse grid, category chips, search)
│   │   ├── listing/         # ListingDetailScreen, CreateListingScreen, MyListingsScreen
│   │   ├── profile/         # ProfileScreen, EditProfileScreen
│   │   └── rating/          # RateSellerScreen
│   ├── services/            # AuthService, ListingService, ChatService, RatingService
│   └── widgets/             # Reusable UI (ListingCard, ChatBubble, RatingStars, CustomButton, etc.)
└── test/
    └── widget_test.dart     # Unit & Widget tests
```

---

## 🗄️ Firestore Data Model

### `users/{uid}`
```json
{
  "name": "Jane Doe",
  "email": "jane@university.edu",
  "photoUrl": "https://storage.googleapis.com/...",
  "rating": 4.8,
  "ratingCount": 12,
  "joinedAt": "2026-10-01T10:00:00Z",
  "fcmToken": null
}
```

### `listings/{id}`
```json
{
  "sellerId": "user_123",
  "title": "Calculus: Early Transcendentals 8th Edition",
  "description": "Mint condition, no highlighting. Can meet at main library.",
  "price": 45.00,
  "category": "Textbooks",
  "images": ["https://storage.googleapis.com/..."],
  "status": "available",
  "createdAt": "2026-10-22T14:30:00Z",
  "searchKeywords": ["calculus", "early", "transcendentals", "textbooks"]
}
```

### `chats/{chatId}`
- **Note**: `chatId = sorted(uidA + "_" + uidB)`
```json
{
  "members": ["uid_1", "uid_2"],
  "lastMessage": "Sounds great! See you outside the student union.",
  "lastMessageAt": "2026-10-22T15:00:00Z",
  "participants": {
    "uid_1": { "name": "Jane", "photoUrl": "https://..." },
    "uid_2": { "name": "Alex", "photoUrl": null }
  }
}
```

### `chats/{chatId}/messages/{msgId}`
```json
{
  "senderId": "uid_1",
  "text": "Are you free to meet around 2 PM?",
  "sentAt": "2026-10-22T15:00:00Z",
  "read": true
}
```

### `ratings/{id}`
```json
{
  "fromUserId": "uid_2",
  "toUserId": "uid_1",
  "listingId": "listing_456",
  "stars": 5.0,
  "comment": "Quick reply, super easy transaction on campus!",
  "createdAt": "2026-10-22T16:00:00Z"
}
```

---

## ⚙️ Firebase Setup & Configuration

### 1. Create a Firebase Project
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and name it (e.g. `campusconnect-app`).
3. Disable Google Analytics (optional for local/academic projects).

### 2. Enable Authentication
1. In Firebase Console, go to **Build > Authentication**.
2. Click **Get Started** and select **Email/Password**.
3. Toggle **Enable** and click **Save**.

### 3. Create Cloud Firestore Database
1. Go to **Build > Firestore Database**.
2. Click **Create database** in **Production mode**.
3. Choose your nearest Cloud region (e.g., `us-central1`).

### 4. Create Firebase Storage Bucket
1. Go to **Build > Storage**.
2. Click **Get Started** in **Production mode**.

### 5. Link Project via FlutterFire CLI
Ensure you have the FlutterFire CLI installed:
```bash
dart pub global activate flutterfire_cli
```
Run the configure command in the `campus_connect` directory:
```bash
flutterfire configure
```
Select your Firebase project and select the target platforms (Android, iOS, Web, Windows, macOS). This will automatically update `lib/firebase_options.dart`.

### 6. Deploy Security Rules
Using the Firebase CLI:
```bash
# Login to Firebase
firebase login

# Deploy both Firestore and Storage security rules
firebase deploy --only firestore:rules,storage
```

---

## 🧪 Testing the Application

### Running the App
```bash
cd campus_connect
flutter run
```

### Verifying Tests and Static Analysis
```bash
flutter test
flutter analyze
```

### Solo CS Project Demo Flow (5-Minute Walkthrough)
1. **Registration**: Open the app and click **Register Here**. Create User A (`alex@university.edu`).
2. **Post an Item**: Tap the **Sell Item** button. Select a textbook photo, enter \$35, select "Textbooks", and publish.
3. **Browse & Search**: Type "Calculus" in the search bar or tap the "Textbooks" chip to view filtering in action.
4. **Chat Test**: Log in on a second simulator/device as User B (`jane@university.edu`). Open Alex's listing and tap **Chat with Seller**. Send a message.
5. **Real-Time Messaging**: Observe instantaneous message delivery and read receipts in User A's **Chats** tab.
6. **Reputation Review**: From the listing, tap **Rate Seller**. Select 5 stars, write feedback, and submit. Check Alex's profile to verify the updated average score and review history.
