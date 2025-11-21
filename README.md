# HaHaHa Flashcard

A Flutter project for flashcard application with OCR text recognition and Firebase integration.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Firebase project setup

### Firebase Setup

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase for your project:
   ```bash
   flutterfire configure
   ```

3. This will generate `lib/firebase_options.dart` file with your Firebase configuration.

**Note:** The `firebase_options.dart` file is excluded from version control for security reasons. Each developer needs to generate their own file using the FlutterFire CLI.

### OpenAI API Setup (for ChatGPT word lookup)

1. Get your OpenAI API key from: https://platform.openai.com/api-keys

2. Create a `.env` file in the project root:
   ```bash
   cp .env.example .env
   ```

3. Edit `.env` file and add your API key:
   ```
   OPENAI_API_KEY=sk-your-actual-api-key-here
   ```

**Note:** The `.env` file is excluded from version control for security reasons. Never commit your actual API key to git.

### Running the App

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Features

- Camera-based text recognition using ML Kit
- Word lookup with irregular verb support
- Firebase Firestore integration for word definitions
- Firebase Authentication

## Security Note

### Firebase Configuration
If you've exposed Firebase API keys in your repository, please:
1. Rotate your Firebase API keys in the Firebase Console
2. Update your Firebase security rules
3. Regenerate `firebase_options.dart` using `flutterfire configure`

### Environment Variables
- Never commit `.env` file to version control
- The `.env` file contains sensitive API keys
- Use `.env.example` as a template for other developers
- If you've accidentally committed `.env`:
  1. Remove it from git history: `git rm --cached .env`
  2. Add to `.gitignore` (already done)
  3. Rotate your API keys
  4. Commit the changes