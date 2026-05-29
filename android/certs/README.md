# Play signing certificates (reference)

## App signing key (Google holds the private key)

File: `play-app-signing-cert.der` — public certificate only. **Cannot** be used to sign `.aab` files locally.

Use these fingerprints when registering the app with API providers (Firebase, Google Maps, OAuth, etc.):

| Algorithm | Fingerprint |
|-----------|-------------|
| MD5 | `52:1F:38:30:10:CD:6A:B0:84:41:60:02:F0:34:EB:18` |
| SHA-1 | `5A:18:6B:DE:CC:C0:A5:1A:A9:C6:D1:E4:B8:34:2C:25:EB:67:1C:14` |
| SHA-256 | `34:AF:06:D3:AD:77:5D:8D:A5:7D:5E:27:DC:17:CE:2F:2D:45:D3:A3:94:52:73:91:CF:B9:C7:53:E2:1C:5F:4A` |

In [Firebase Console](https://console.firebase.google.com) → Project settings → Your apps → Android app → add the **SHA-1** (and SHA-256 if asked) under **App signing key certificate**, not only the upload key.

## Upload key (you must have this to build releases)

Play Console → **App integrity** → **App signing** → scroll to **Upload key certificate** (separate section above/below app signing key).

You need:

- `android/upload-keystore.jks` — private keystore (`.jks`), **not** the `.der` file
- `android/key.properties` — passwords and alias

Without the upload keystore, `flutter build appbundle` cannot produce a bundle Play will accept.

### If Play says “fingerprints will be shown after you upload your first app bundle”

No upload key is registered yet (debug uploads do not count). **Create a new upload keystore** — you are not replacing a lost Play-registered key:

```bash
./android/scripts/create-upload-keystore.sh
flutter build appbundle --release
```

After the first **accepted** release-signed `.aab`, Play will show upload key fingerprints in App integrity.

The **Digital Asset Links** JSON on that page uses the **app signing** SHA-256 (`34:AF:06:...`), not your upload key. Use it for website ↔ app links only.
