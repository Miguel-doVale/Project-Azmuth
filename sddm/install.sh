#!/usr/bin/env bash
# Project Azmuth — instala o tema de login no SDDM (precisa de sudo).
#   bash sddm/install.sh            instala/atualiza e ativa
#   bash sddm/install.sh --remove   volta ao tema padrão do SDDM
set -euo pipefail
SRC="$(dirname "$(readlink -f "$0")")/azmuth"
DEST=/usr/share/sddm/themes/azmuth
CONF=/etc/sddm.conf.d/azmuth.conf

if [[ "${1:-}" == "--remove" ]]; then
    sudo rm -rf "$DEST" "$CONF"
    echo "Tema Azmuth removido; SDDM volta ao padrão."
    exit 0
fi

sudo rm -rf "$DEST"
sudo cp -r "$SRC" "$DEST"
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=azmuth\n' | sudo tee "$CONF" >/dev/null
echo "Tema Azmuth instalado em $DEST e ativado ($CONF)."
echo "Vale no próximo login (ou: sudo systemctl restart sddm — encerra a sessão atual!)."
