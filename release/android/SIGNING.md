# Android signing

1. Create an upload key (once, keep it safe and backed up):
   `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Local builds: create `app/android/key.properties` (git-ignored):
   ```
   storeFile=../upload.jks   # path relative to app/android/app
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
3. CI: add repository secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. The workflow writes `key.properties` and signs the AAB/APK.
4. Enrol in Play App Signing when creating the app in Play Console and upload the first AAB.
