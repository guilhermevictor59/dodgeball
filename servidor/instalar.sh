#!/bin/bash
# Instala o servidor 24h da Sala 1 (Orange Box: Queimada) numa máquina Ubuntu (feito para a Oracle Cloud Always Free).
# Uso (na máquina, pelo SSH ou Cloud Shell):
#   curl -fsSL https://guilhermevictor59.github.io/dodgeball/servidor/instalar.sh | sudo bash
# Pode rodar de novo quando quiser: ele atualiza tudo e mantém o que já existe.
set -euo pipefail

GODOT=4.7.2
CADDY=2.8.4
SITE=https://guilhermevictor59.github.io/dodgeball
case "$(uname -m)" in
  aarch64) GZ=linux.arm64; CZ=arm64 ;;
  x86_64) GZ=linux.x86_64; CZ=amd64 ;;
  *) echo "Processador não suportado: $(uname -m)"; exit 1 ;;
esac

echo "== Instalando programas"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get install -y -q unzip curl iptables-persistent >/dev/null || apt-get install -y -q unzip curl

id dodgeball >/dev/null 2>&1 || useradd -r -m -d /var/lib/dodgeball -s /usr/sbin/nologin dodgeball
mkdir -p /opt/dodgeball /var/lib/caddy /etc/caddy
cd /opt/dodgeball

echo "== Baixando o Godot $GODOT ($GZ)"
if [ ! -x godot ] || ! ./godot --headless --version 2>/dev/null | grep -q "^$GODOT"; then
  curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT}-stable/Godot_v${GODOT}-stable_${GZ}.zip"
  unzip -o -q godot.zip
  mv -f "Godot_v${GODOT}-stable_${GZ}" godot
  chmod +x godot
  rm -f godot.zip
fi

echo "== Baixando o jogo"
curl -fsSL -o jogo.pck "$SITE/index.pck"
curl -fsSL -o atualizar.sh "$SITE/servidor/atualizar.sh"
chmod +x atualizar.sh

echo "== Baixando o Caddy $CADDY (cuida do https)"
if ! /usr/local/bin/caddy version 2>/dev/null | grep -q "v$CADDY"; then
  curl -fsSL -o caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY}/caddy_${CADDY}_linux_${CZ}.tar.gz"
  tar xzf caddy.tar.gz caddy
  mv -f caddy /usr/local/bin/caddy
  rm -f caddy.tar.gz
fi

IP=$(curl -fsS https://api.ipify.org)
HOST="$(echo "$IP" | tr . -).sslip.io"
cat > /etc/caddy/Caddyfile <<CADDYFILE
$HOST {
	handle /jogo* {
		reverse_proxy 127.0.0.1:24680
	}
	handle /status.json {
		header Access-Control-Allow-Origin *
		header Cache-Control no-store
		root * /var/lib/dodgeball
		file_server
	}
	handle {
		respond "Orange Box: Queimada - servidor da Sala 1"
	}
}
CADDYFILE

echo "== Criando os serviços (ligam sozinhos quando a máquina reinicia)"
cat > /etc/systemd/system/dodgeball.service <<UNIT
[Unit]
Description=Orange Box: Queimada - servidor da Sala 1
After=network-online.target

[Service]
User=dodgeball
Environment=HOME=/var/lib/dodgeball
ExecStart=/opt/dodgeball/godot --headless --main-pack /opt/dodgeball/jogo.pck -- --servidor --status=/var/lib/dodgeball/status.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/dodgeball-caddy.service <<UNIT
[Unit]
Description=Caddy (https do servidor da Sala 1)
After=network-online.target

[Service]
Environment=XDG_DATA_HOME=/var/lib/caddy XDG_CONFIG_HOME=/var/lib/caddy
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

# a cada 10 minutos confere se tem versão nova do jogo no site
cat > /etc/systemd/system/dodgeball-atualizar.service <<UNIT
[Unit]
Description=Atualiza o jogo do servidor da Sala 1

[Service]
Type=oneshot
ExecStart=/opt/dodgeball/atualizar.sh
UNIT
cat > /etc/systemd/system/dodgeball-atualizar.timer <<UNIT
[Unit]
Description=Confere versão nova do jogo a cada 10 minutos

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
UNIT

echo "== Liberando as portas 80 e 443 no firewall da máquina"
for p in 80 443; do
  iptables -C INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport $p -j ACCEPT
done
command -v netfilter-persistent >/dev/null && netfilter-persistent save >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl enable --now dodgeball.service dodgeball-caddy.service dodgeball-atualizar.timer >/dev/null
systemctl restart dodgeball.service dodgeball-caddy.service

echo
echo "== Pronto! Conferindo..."
sleep 8
if [ -f /var/lib/dodgeball/status.json ]; then
  echo "Jogo: rodando ($(cat /var/lib/dodgeball/status.json))"
else
  echo "Jogo: ainda não respondeu. Veja com: sudo journalctl -u dodgeball -n 30"
fi
echo
echo "Endereço do servidor: $HOST"
echo "Mande este endereço para o Claude no chat do projeto."
echo "(Se o https não abrir em https://$HOST, confira se as portas 80 e 443 estão liberadas na Security List da Oracle.)"
