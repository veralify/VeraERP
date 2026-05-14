iOS Native App (Swift/SwiftUI)
Android Native App (Kotlin/Jetpack Compose)

## Project Structure

### veralify-ios/
- VeralifyApp.swift: Main app with SwiftUI
- Features: Login, Dashboard, Profile tabs
- Authentication: Google & Apple OAuth ready
- State Management: ObservedObject/StateObject
- Responsive: Supports iPhone and iPad

### veralify-android/
- MainActivity.kt: Main activity with Jetpack Compose
- Features: Login, Dashboard, Profile tabs
- Bottom navigation for mobile
- Material 3 design system
- Kotlin coroutines ready for API calls

## Setup

### iOS
1. Open veralify-ios folder in Xcode
2. Configure signing & capabilities
3. Add OAuth credentials
4. Run on simulator or device

### Android
1. Open veralify-android in Android Studio
2. Sync gradle files
3. Configure OAuth credentials in ManifestPlaceholders
4. Run on emulator or device

## Integration Points

Both apps are ready for:
- Supabase REST API integration
- Google OAuth (via native frameworks)
- Apple OAuth (via native frameworks)
- Document management APIs
- User role-based access control
