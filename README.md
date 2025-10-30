# TriGoRide

## 🚖 Oroquieta City Based Tricycle Booking App

A modern Flutter application connecting passengers and tricycle drivers in Oroquieta City with real-time booking, GPS tracking, and multi-channel notifications.

## ✨ Key Features

- 🎤 **Voice Hailing** - Book rides using speech-to-text
- 🗺️ **Real-time GPS Tracking** - Track your ride with Google Maps
- � **Smart Map Centering** - Auto-fit bounds showing route & driver location
- 💰 **Per-Head Fare Calculation** - Normal rides charge per passenger, special rides have ₱60 minimum
- 📊 **Enhanced Booking Cards** - Complete trip details with pickup/dropoff addresses
- �📱 **Push Notifications** - Instant updates via Firebase Cloud Messaging
- 📧 **Email Receipts** - Professional trip receipts via SendGrid
- 💬 **SMS Alerts** - Booking confirmations via Semaphore Philippines
- ⭐ **Rating System** - Rate and review drivers
- 🔐 **Secure Authentication** - Email/Password and Google Sign-In with friendly error messages
- 🌓 **Dark Mode** - Adaptive theming for day and night
- 🤖 **ML Integration** - TensorFlow Lite for smart driver matching

## 🆕 Recent Updates (Latest Session)

### UI/UX Improvements

- ✅ **Fixed layout rendering** - Resolved RenderBox errors in booking cards
- ✅ **Map centering** - Routes now properly centered with all markers visible
- ✅ **Driver location tracking** - Map bounds include driver's current position
- ✅ **Enhanced cards** - Added pickup/dropoff addresses, passenger count, and fare details

### Fare System

- ✅ **Per-head pricing** - Normal rides multiply by passenger count
- ✅ **Special ride minimum** - Enforced ₱60 minimum for special bookings
- ✅ **Transparent calculations** - Clear breakdown of base fare + service fee

### Error Handling

- ✅ **Friendly error messages** - No more raw Firebase errors
- ✅ **Login errors** - Clear messages for wrong password, account not found, etc.
- ✅ **Registration errors** - Helpful feedback for existing accounts, weak passwords, etc.

## 📚 Documentation

- **[Complete Documentation](DOCUMENTATION.md)** - Full technical specifications
- **[SMS & Email Setup Guide](SMS_EMAIL_SETUP.md)** - Configure notifications

## 🚀 Quick Start

1. **Prerequisites**: Flutter 3.6.0+, Firebase project, API keys
2. **Clone**: `git clone https://github.com/noneiann/TriGoRide.git`
3. **Install**: `flutter pub get`
4. **Configure**: Update `.env` with your API keys
5. **Run**: `flutter run`

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed installation instructions.

## 🔧 Configuration Required

### Essential APIs

- **Firebase** (Authentication, Firestore, FCM)
- **Google Maps** (Maps, Directions, Places, Geocoding)

### Optional (Notifications)

- **SendGrid** - Email receipts (100 free/day)
- **Semaphore API** - SMS alerts for Philippine numbers

See [SMS_EMAIL_SETUP.md](SMS_EMAIL_SETUP.md) for setup instructions.

## 📱 Download

Coming soon to Google Play Store and Apple App Store!

## 👥 Team

**InnoVision Development Team**  
Oroquieta City, Philippines

## 📄 License

Private - All Rights Reserved © 2025
