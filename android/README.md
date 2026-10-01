# GOD MODE 안드로이드 앱

저장소 루트의 `index.html`을 그대로 띄우는 WebView 앱입니다.

- 화면은 앱 안에서 `https://appassets.androidplatform.net/index.html`로 열립니다. 보안 출처라서 localStorage와 crypto.subtle을 쓸 수 있습니다.
- 바이낸스 REST 호출은 네이티브 HTTP 브리지(`AndroidHttp`)로 보냅니다. 그래서 브라우저 CORS 제약이 없습니다.
- 실시간 시세(WebSocket)는 WebView가 직접 연결합니다.

## 설치

1. `dist/godmode.apk`를 폰으로 받습니다.
2. 파일을 열면 "출처를 알 수 없는 앱 설치"를 허용하라는 안내가 뜹니다. 허용하고 설치합니다.
3. Play 프로텍트 경고가 뜨면 "무시하고 설치"를 누릅니다. 개인용 앱이라 Play 스토어 서명이 없어서 뜨는 경고입니다.

## 빌드

Android SDK 없이 Java 17+와 curl만 있으면 됩니다.

```bash
./android/build.sh        # → android/dist/godmode.apk
```

- **사용 도구**: Apktool 2.10.0(aapt2와 smali 포함)과 uber-apk-signer 1.3.0. 처음 빌드할 때 GitHub 릴리스에서 `android/.tools/`로 받습니다.
- **앱 코드**: `app/smali/com/godmode/trader/`에 Dalvik 어셈블리(smali)로 직접 작성했습니다.
  - `MainActivity`: WebView 설정
  - `AssetClient`: assets 서빙
  - `Bridge`, `HttpTask`: 네이티브 HTTP
  - `JsRunnable`: 결과를 JS로 전달
- **버전**: versionCode는 git 커밋 수로 자동 증가합니다.

## 서명 키

`godmode-release.jks`(비밀번호 `godmode`)로 서명합니다.

- **같은 키로 서명해야** 폰에서 기존 앱을 지우지 않고 업데이트할 수 있습니다. 앱을 지우면 저장된 API 키도 함께 지워집니다.
- 이 저장소는 개인용이라 키를 커밋해 두었습니다. 저장소를 공개할 경우에는 키를 저장소 밖으로 옮기고 `GODMODE_KEYSTORE` / `GODMODE_KEYSTORE_PASS` 환경변수로 지정하세요.
