#!/usr/bin/env bash
# Monta o texto da release no GitHub: como baixar, as novidades desde a
# versão anterior (os commits, com o detalhe de cada um) e tudo o que o
# aplicativo tem (ci/recursos.md). Uso: bash ci/notas.sh [saida.md]
set -euo pipefail

saida=${1:-notas.md}
anterior=$(git describe --tags --abbrev=0 2>/dev/null || true)
intervalo=${anterior:+$anterior..}HEAD

{
  echo 'Baixe o arquivo do seu aparelho:'
  echo '- **PAU-Android.apk**: celular Android'
  echo '- **PAU-Instalador-Windows.exe**: instalador para Windows'
  echo '- **PAU-Windows-portatil.zip**: Windows sem instalar (descompacte e abra cris_ficha.exe)'
  echo
  echo "## Novidades desta versão${anterior:+ (desde a $anterior)}"
  echo
  for c in $(git rev-list --reverse --no-merges "$intervalo"); do
    echo "- **$(git log -1 --format=%s "$c")**"
    # o corpo do commit, sem a assinatura, como itens dentro do título
    git log -1 --format=%b "$c" | grep -v '^Co-Authored-By' | sed '/^[[:space:]]*$/d; s/^/  /' || true
  done
  echo
  cat ci/recursos.md
} > "$saida"
