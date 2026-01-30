# Google OAuth — Android (odcisk SHA-1 i nazwa pakietu)

## Jeśli nadal ApiException: 10 — checklist

1. **Ten sam projekt** — Android OAuth client musi być w **tym samym** Google Cloud projekcie, w którym jest Web Client ID (ten z `.env`). Sprawdź w Credentials: Web client i Android client na jednej liście.
2. **SHA-1 z debug** — przy `flutter run` używany jest **debug** keystore. W Credentials musi być SHA-1 z **debug**, nie z release.
3. **Package name 1:1** — dokładnie `com.example.mobile` (bez spacji, bez wielkiej litery w `example`).
4. **Poczekaj 2–5 minut** — po utworzeniu/zmianie OAuth client Google może potrzebować chwili. Spróbuj ponownie wejść przez Google.
5. **Jeden Android client** — dla tego samego package name + SHA-1 wystarczy jeden Android client. Nie twórz kilku „na próbę”.

---

## Dla tworzenia OAuth Client ID (typ: Android)

### 1. **Nazwa pakietu (Package name)**
```
com.example.mobile
```

### 2. **Odcisk SHA-1 (tylko debug)**

**Sposób A — keytool (Windows, bez Gradle):**
```powershell
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```
W wyniku skopiuj linię **SHA1:** (np. `AA:BB:CC:DD:...`).

**Sposób B — Gradle:**
```powershell
cd D:\_PROJECTS\_Henzo\apps\mobile\android
.\gradlew signingReport
```
Znajdź **Variant: debug** → **SHA-1**.

---

## W Google Cloud Console

1. [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials**.
2. Upewnij się, że wybrany jest **ten sam projekt**, w którym masz Web Client ID (używany w Supabase i `.env`).
3. **Create Credentials** → **OAuth client ID**.
4. **Application type:** **Android**.
5. **Package name:** `com.example.mobile` (wklej, nie wpisuj z pamięci).
6. **SHA-1 certificate fingerprint:** wklej SHA-1 z keytool / signingReport (debug).
7. **Create**.

Web Client ID nie zmieniaj — ten sam co w Supabase i w `.env` (`EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID`).
