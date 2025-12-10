# TriGoRide

<div align="center">

![TriGoRide Logo](assets/TriGoRideLogo.png)

**Oroquieta City Based Tricycle Booking Application**

[![Flutter](https://img.shields.io/badge/Flutter-3.6.0-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-red?style=for-the-badge)](LICENSE)

_A modern, intelligent tricycle booking platform connecting passengers and drivers in Oroquieta City_

[Features](#-key-features) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Team](#-team)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Recent Updates](#-recent-updates)
- [Technology Stack](#-technology-stack)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration-required)
- [Documentation](#-documentation)
- [Download](#-download)
- [Team](#-team)
- [License](#-license)

---

## 🌟 Overview

**TriGoRide** is a comprehensive, location-based tricycle booking application specifically designed for Oroquieta City. The app serves two distinct user roles: passengers who need rides and tricycle drivers looking for bookings.

---

## ✨ Key Features

- 🎤 **Voice Hailing** - Book rides using speech-to-text
- 🗺️ **Real-time GPS Tracking** - Track your ride with Google Maps
- 📍 **Smart Map Centering** - Auto-fit bounds showing route & driver location
- 💰 **Per-Head Fare Calculation** - Normal rides charge per passenger, special rides have ₱60 minimum
- 📊 **Enhanced Booking Cards** - Complete trip details with pickup/dropoff addresses
- 📱 **Push Notifications** - Instant updates via Firebase Cloud Messaging
- 📧 **Email Receipts** - Professional trip receipts via SendGrid
- 💬 **SMS Alerts** - Booking confirmations via Semaphore Philippines
- ⭐ **Rating System** - Rate and review drivers
- 🔐 **Secure Authentication** - Email/Password and Google Sign-In with friendly error messages
- 🌓 **Dark Mode** - Adaptive theming for day and night
- 🤖 **ML Integration** - TensorFlow Lite for smart driver matching

---

## 🆕 Recent Updates

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

---

## 🏗️ Technology Stack

### **Frontend Framework**

```yaml
Flutter SDK: ^3.6.0
Dart SDK: ^3.6.0
```

### **Backend Services**

- **Firebase Authentication** - User management
- **Cloud Firestore** - NoSQL database
- **Firebase Realtime Database** - Live location tracking
- **Firebase Cloud Messaging** - Push notifications

### **Third-Party APIs**

- **Google Maps Platform** - Maps, Directions, Places, Geocoding
- **Cloudinary** - Image CDN
- **SendGrid** - Email notifications
- **Semaphore** - SMS notifications (Philippines)

---

## 🚀 Quick Start

### **Prerequisites**

- Flutter 3.6.0 or higher
- Firebase project
- Google Maps API key
- SendGrid API key (optional)
- Semaphore API key (optional)

### **Installation**

1. **Clone the repository**

   ```bash
   git clone https://github.com/noneiann/TriGoRide.git
   cd TriGoRide
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Create a `.env` file in the project root:

   ```env
   GOOGLEMAPS_APIKEY=your_google_maps_api_key
   FCM_SERVER_KEY=your_fcm_server_key
   SENDGRID_API_KEY=your_sendgrid_api_key
   SENDGRID_FROM_EMAIL=noreply@trigoride.com
   SENDGRID_FROM_NAME=TriGoRide
   SEMAPHORE_API_KEY=your_semaphore_api_key
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed installation instructions.

---

## 🔧 Configuration Required

### **Essential APIs**

- **Firebase** (Authentication, Firestore, Realtime Database, FCM)
- **Google Maps** (Maps, Directions, Places, Geocoding)

### **Optional (Notifications)**

- **SendGrid** - Email receipts (100 free emails/day)
- **Semaphore API** - SMS alerts for Philippine numbers

---

## � Documentation

- **[Complete Documentation](DOCUMENTATION.md)** - Full technical specifications, architecture, and API references

---

## �📱 Download

Coming soon to Google Play Store and Apple App Store!

---

## 👥 Team

**InnoVision Development Team**  
Oroquieta City, Philippines

**Repository:** [github.com/noneiann/TriGoRide](https://github.com/noneiann/TriGoRide)

---

## 📄 License

**Private - All Rights Reserved**

Copyright © 2025 InnoVision, TriGoRide Development Team

This application is proprietary software. Unauthorized copying, distribution, or modification is strictly prohibited.

---

<div align="center">

**TriGoRide** - _Connecting Oroquieta City, One Ride at a Time_ 🚖

[![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Powered by Firebase](https://img.shields.io/badge/Powered%20by-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)

</div>
