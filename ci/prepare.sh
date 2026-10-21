#!/usr/bin/env bash
# Gera as pastas android/ e windows/ (se faltarem) e aplica os ajustes do app.
set -euo pipefail
flutter create . --project-name cris_ficha --org br.cris --platforms android,windows

# Teste padrao do template nao serve para este app
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

# ---- Android ----
G=android/app/build.gradle.kts
[ -f "$G" ] || G=android/app/build.gradle
sed -i.bak -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 24/' "$G"
M=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i.bak 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#&\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$M"
fi
sed -i.bak 's/android:label="cris_ficha"/android:label="P.A.U"/' "$M"
rm -f "$G.bak" "$M.bak"

# ---- Windows ----
if [ -f windows/runner/main.cpp ]; then
  sed -i.bak 's/L"cris_ficha"/L"P.A.U"/' windows/runner/main.cpp
  rm -f windows/runner/main.cpp.bak
fi
# nome que o Windows mostra (gerenciador de tarefas, propriedades do .exe)
if [ -f windows/runner/Runner.rc ]; then
  sed -i.bak -E 's/(VALUE "(FileDescription|ProductName)", )"cris_ficha"/\1"P.A.U"/' windows/runner/Runner.rc
  rm -f windows/runner/Runner.rc.bak
fi
echo "Preparado."
