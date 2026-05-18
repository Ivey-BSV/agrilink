# Publish CAP to Google Play Store

## Prerequisites: Android SDK (ANDROID_HOME)

Flutter needs the **Android SDK** to build the app bundle. If you see:

> No Android SDK found. Try setting the ANDROID_HOME environment variable.

do the following.

**1. Install the Android SDK (if needed)**

- Open **Android Studio**.
- Go to **Android Studio → Settings** (or **Preferences** on Mac) → **Languages & Frameworks → Android SDK** (or **Appearance & Behavior → System Settings → Android SDK**).
- Note the **Android SDK Location** (e.g. `~/Library/Android/sdk` or `/Users/YourName/Library/Android/sdk`). If it says “SDK not found” or the path is empty, click **Edit** or **Next** and install the SDK into the default folder.
- In the **SDK Platforms** tab, install at least one platform (e.g. the latest or the one your project targets).
- In the **SDK Tools** tab, ensure **Android SDK Build-Tools** and **Android SDK Platform-Tools** are installed. Apply and finish.

**2. Set ANDROID_HOME**

In a terminal, for the **current session**:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
```

To make it **permanent** (for zsh on Mac), add that line to `~/.zshrc`:

```bash
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH="$PATH:$ANDROID_HOME/platform-tools"' >> ~/.zshrc
source ~/.zshrc
```

If your SDK is in a different folder, use that path instead of `$HOME/Library/Android/sdk`. Then run `flutter build appbundle` again.

---

## Prerequisites: Java (for `keytool`)

`keytool` is used to create the upload keystore. It comes with a **JDK** (Java Development Kit). If you see:

> Unable to locate a Java Runtime.

install a JDK first.

**Option A – Homebrew (recommended on Mac):**

```bash
brew install openjdk@17
```

Then either use the full path to `keytool`, or link it so it’s on your `PATH`. After install, Homebrew prints the path; it’s often:

- **Apple Silicon:** `/opt/homebrew/opt/openjdk@17/bin/keytool`
- **Intel:** `/usr/local/opt/openjdk@17/bin/keytool`

Run the `keytool` command below using that path, e.g.:

```bash
/opt/homebrew/opt/openjdk@17/bin/keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Option B – Android Studio**

If Android Studio is installed, you can use its bundled JDK:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Option C – Manual install**

Download and install a JDK from [Adoptium](https://adoptium.net/) or [Oracle](https://www.oracle.com/java/technologies/downloads/), then run `keytool` from that JDK’s `bin` directory.

---

## What is an App Bundle?

An **Android App Bundle** (`.aab`) is the upload format for Google Play. It is not an APK. Play Store uses it to generate optimized APKs per device (architecture, screen, language). You must upload an `.aab`; Play does not accept APKs for new apps.

---

## 1. Create an upload keystore (one‑time)

From the project root:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Use strong **store** and **key** passwords and save them safely.
- Use `upload` as the key alias (or match `keyAlias` in `key.properties`).
- `upload-keystore.jks` is already in `.gitignore`; do not commit it.

---

## 2. Create `key.properties`

In `android/`:

```bash
cd android
cp key.properties.example key.properties
```

Edit `android/key.properties`:

```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

- Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with the passwords from step 1.
- `storeFile` is relative to the `android/` folder. If the JKS is elsewhere, use a path relative to `android/` or an absolute path (avoid committing absolute paths).

`key.properties` is in `.gitignore`; do not commit it.

---

## 3. Build the App Bundle

From the project root:

```bash
flutter clean
flutter pub get
flutter build appbundle
```

---

## 4. File to upload to Play Console

After a successful build:

**Path:**

```
build/app/outputs/bundle/release/app-release.aab
```

**What to do in Play Console:**

1. Open your app → **Production** (or a testing track).
2. Create a new release.
3. Upload `app-release.aab` in the **App bundle** section (drag & drop or choose file).
4. Add release notes and finish the release.

---

## 5. Application ID

The app is configured with:

- **Application ID:** `com.agrilink.cap`

If you want a different ID (e.g. `com.yourcompany.cap`), change `applicationId` in `android/app/build.gradle.kts`. **Do not change it after the first publish** (it defines your app’s identity on Play).

---

## 6. Google Play App Signing

For new apps, Play uses **Play App Signing**:

- You sign the bundle with your **upload key** (the one in `upload-keystore.jks`).
- Play signs the app with the **app signing key** (managed by Google).

When you upload the first `.aab`, Play may ask you to enroll in Play App Signing and to register your upload key. Keep `upload-keystore.jks` and both passwords in a safe place; you need them for all future releases.

---

## 7. If `flutter build appbundle` or `keytool` fails

- **“No Android SDK found. Try setting the ANDROID_HOME environment variable”**  
  Install the Android SDK via Android Studio (see **Prerequisites: Android SDK** above), then set `ANDROID_HOME` to your SDK path (e.g. `export ANDROID_HOME=$HOME/Library/Android/sdk`) and run the build again.

- **“Release app bundle failed to strip debug symbols from native libraries”**  
  Often fixed by installing **Android SDK Command-line Tools (latest)** and ensuring they’re on your PATH:
  1. In Android Studio: **Settings/Preferences → Languages & Frameworks → Android SDK → SDK Tools**.
  2. Check **Android SDK Command-line Tools (latest)** and **NDK (Side by side)** if needed. Click **Apply**.
  3. In a terminal: `flutter doctor --android-licenses` and accept all.
  4. Add to `~/.zshrc` (if not already there):  
     `export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin` and  
     `export PATH=$PATH:$ANDROID_HOME/platform-tools`  
     then run `source ~/.zshrc`.
  5. Run:  
     `flutter clean`  
     `cd android && ./gradlew clean && cd ..`  
     `flutter pub get`  
     `flutter build appbundle`  
  If it still fails, try upgrading Flutter (`flutter upgrade`).

- **“Unable to locate a Java Runtime” (when running `keytool`)**  
  Install a JDK (see **Prerequisites: Java** above) and run `keytool` using that JDK’s `bin/keytool`, or add that `bin` to your `PATH`.

- **“key.properties not found” or signing errors**  
  Ensure `android/key.properties` exists and `storeFile` points to `upload-keystore.jks` in `android/` (or the path you use).

- **“Keystore was tampered with, or password was incorrect”**  
  Check `storePassword` and `keyPassword` in `key.properties`.

- **“alias not found”**  
  Ensure the alias in `key.properties` matches the one used in `keytool -alias upload`.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Create `android/upload-keystore.jks` with `keytool` |
| 2 | Create `android/key.properties` from `key.properties.example` and set passwords and `storeFile` |
| 3 | Run `flutter build appbundle` |
| 4 | Upload **`build/app/outputs/bundle/release/app-release.aab`** in Play Console |
