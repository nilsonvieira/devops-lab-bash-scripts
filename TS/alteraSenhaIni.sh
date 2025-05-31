#!/bin/bash
if [ $# -ne 2 ]; then
  echo "Uso: $0 SENHA_ANTIGA NOVA_SENHA"
  exit 1
fi

SENHA_ANTIGA="$1"
NOVA_SENHA="$2"
CAMINHO_BASE="/opt/ts/apps"

find "$CAMINHO_BASE" -type f -name "*.ini" | while read -r arquivo; do
  if grep -q "enable-secret-templating=true" "$arquivo"; then
    echo "Ignorando (possui enable-secret-templating=true): $arquivo"
    continue
  fi

  if grep -q "$SENHA_ANTIGA" "$arquivo"; then
    echo "Atualizando senha em: $arquivo"
    sed -i "s/$SENHA_ANTIGA/$NOVA_SENHA/g" "$arquivo"
  fi
done

echo "Processo concluído."