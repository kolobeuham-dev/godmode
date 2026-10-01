#!/usr/bin/env bash
# GOD MODE 안드로이드 APK 빌드 (Android SDK 불필요)
#   필요: Java 17+, curl
#   도구: Apktool(aapt2 + smali 포함), uber-apk-signer(zipalign + v1/v2/v3 서명) — GitHub 릴리스에서 자동 다운로드
#   결과: android/dist/godmode.apk
set -euo pipefail
cd "$(dirname "$0")"
TOOLS=.tools; mkdir -p "$TOOLS" dist
[ -f "$TOOLS/apktool.jar" ] || curl -fsSL -o "$TOOLS/apktool.jar" https://github.com/iBotPeaches/Apktool/releases/download/v2.10.0/apktool_2.10.0.jar
[ -f "$TOOLS/signer.jar" ]  || curl -fsSL -o "$TOOLS/signer.jar"  https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar

# 웹 화면은 저장소 루트의 index.html 을 그대로 사용
mkdir -p app/assets && cp ../index.html app/assets/index.html

# 버전: versionCode 는 커밋 수, versionName 은 1.0.<커밋 수>
VC=$(git rev-list --count HEAD 2>/dev/null || echo 1)
sed -i -E "s/versionCode: '[0-9]+'/versionCode: '$VC'/; s/versionName: '[^']*'/versionName: '1.0.$VC'/" app/apktool.yml

# 서명 키: 같은 키로 서명해야 폰에서 업데이트 설치가 됨 (없으면 새로 생성)
KS=${GODMODE_KEYSTORE:-godmode-release.jks}; PASS=${GODMODE_KEYSTORE_PASS:-godmode}
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass "$PASS" -keypass "$PASS" -alias godmode \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=GOD MODE, O=godmode" >/dev/null 2>&1

rm -rf build-tmp && java -jar "$TOOLS/apktool.jar" b app -o build-tmp/unsigned.apk --use-aapt2
java -jar "$TOOLS/signer.jar" -a build-tmp/unsigned.apk -o build-tmp/out --ks "$KS" --ksAlias godmode --ksPass "$PASS" --ksKeyPass "$PASS" --allowResign >/dev/null
mv build-tmp/out/*.apk dist/godmode.apk && rm -rf build-tmp
java -jar "$TOOLS/signer.jar" -a dist/godmode.apk --onlyVerify | grep -E "VERIFY|signature|scheme" | head -5
echo "OK → $(pwd)/dist/godmode.apk (versionCode $VC)"
