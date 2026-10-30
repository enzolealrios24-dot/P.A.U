#!/usr/bin/env bash
# Monta o texto da release no GitHub a partir do README.md, que é o log do
# aplicativo: como baixar, as novidades da versão (a seção "### vX" do
# histórico) e tudo o que o app tem. Sem a seção da versão no README, as
# novidades são os commits desde a versão anterior.
# Uso: bash ci/notas.sh saida.md 1.0.41
set -euo pipefail

saida=${1:-notas.md}
versao=${2:-}

# as linhas de uma seção do README: do título até o próximo do mesmo nível
# (ou de nível acima), sem o próprio título
secao() {
  awk -v titulo="$1" -v nivel="$2" '
    index($0, titulo) == 1 { dentro = 1; next }
    dentro && match($0, /^#+ /) && RLENGTH - 1 <= nivel { exit }
    dentro { print }
  ' README.md
}

{
  echo 'Baixe o arquivo do seu aparelho:'
  echo '- **PAU-Android.apk**: celular Android'
  echo '- **PAU-Instalador-Windows.exe**: instalador para Windows'
  echo '- **PAU-Windows-portatil.zip**: Windows sem instalar (descompacte e abra cris_ficha.exe)'
  echo
  echo '## Novidades desta versão'
  novidades=$( [ -n "$versao" ] && secao "### v$versao " 3 || true )
  if [ -n "$(echo "$novidades" | tr -d '[:space:]')" ]; then
    echo "$novidades"
  else
    anterior=$(git describe --tags --abbrev=0 2>/dev/null || true)
    echo
    for c in $(git rev-list --reverse --no-merges "${anterior:+$anterior..}HEAD"); do
      echo "- $(git log -1 --format=%s "$c")"
    done
  fi
  echo
  echo '## Tudo o que o P.A.U tem'
  secao '## Tudo o que o P.A.U tem' 2
  echo
  echo 'O histórico de todas as versões fica no [README](https://github.com/enzolealrios24-dot/P.A.U#histórico-de-versões).'
} > "$saida"
