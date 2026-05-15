# Safo Android Release Signing Setup

Use this when preparing the first Android release or future store-ready builds.

## 1. Create or obtain the upload keystore

Create a release keystore and store it outside version control.

Recommended location:

- `android/keystores/safo-upload.jks`

## 2. Create `android/key.properties`

Copy the example file:

- `android/key.properties.example`

Create a real local file:

- `android/key.properties`

Expected structure:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../keystores/safo-upload.jks
```

## 3. How the build behaves

Safo now supports both modes:

- if `android/key.properties` exists, release builds use the real release keystore
- if it does not exist, release builds fall back to the debug keystore so local `flutter run --release` still works during development

## 4. Before Play Store / external Android testing

- verify the final `applicationId` is correct:
  - `com.marcelhotka.foodinventory`
- verify the upload keystore is backed up safely
- verify the same keystore will remain available for future updates
- verify versionCode and versionName are incremented correctly

## 5. Do not commit these files

These should stay local and private:

- `android/key.properties`
- `android/*.jks`
- `android/*.keystore`
