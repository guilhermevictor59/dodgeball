#!/bin/bash
# Baixa a versão nova do jogo do site, se tiver, e reinicia o servidor da Sala 1.
set -e
cd /opt/dodgeball
curl -fsSL -z jogo.pck -o jogo.novo https://guilhermevictor59.github.io/dodgeball/index.pck || exit 0
if [ -s jogo.novo ] && ! cmp -s jogo.novo jogo.pck; then
  mv -f jogo.novo jogo.pck
  systemctl restart dodgeball.service
  echo "Jogo atualizado"
fi
rm -f jogo.novo
