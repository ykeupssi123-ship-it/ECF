#!/bin/bash
# ECFBNGX - ECF_ODOO_BLD_NGINX - Reverse-proxy HTTPS
# devant Odoo (URL propre pour la demo, jamais l'IP nue + port 8069)
#
# Certificat auto-signe genere directement ici (projet a une seule
# machine, une seule fois - pas besoin de la chaine PKI complete a
# plusieurs services de WAZ_ELK_FACTORY). Le navigateur du client
# affichera un avertissement de certificat non reconnu la premiere
# fois - normal et attendu pour une demo interne, jamais presente comme
# un defaut cache.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

if ! rpm -q nginx &>/dev/null; then
  echo "[ODOO_015] Installation de nginx..."
  dnf install -y nginx
fi

CERT_DIR="/etc/nginx/ssl"
mkdir -p "$CERT_DIR"
if [ ! -f "${CERT_DIR}/erp.crt" ]; then
  echo "[ODOO_015] Generation d'un certificat auto-signe pour ${ERP_DASHBOARD_FQDN}..."
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "${CERT_DIR}/erp.key" -out "${CERT_DIR}/erp.crt" \
    -subj "/C=CI/O=ERP_CRM_FACTORY/CN=${ERP_DASHBOARD_FQDN}" \
    -addext "subjectAltName=DNS:${ERP_DASHBOARD_FQDN},IP:${FACTORY_HOST_IP}"
  chmod 600 "${CERT_DIR}/erp.key"
fi

cat > /etc/nginx/conf.d/odoo.conf << EOF
upstream odoo {
    server 127.0.0.1:${ODOO_PORT};
}
upstream odoo-longpolling {
    server 127.0.0.1:${ODOO_LONGPOLLING_PORT};
}

server {
    listen 80;
    server_name ${ERP_DASHBOARD_FQDN} ${FACTORY_HOST_IP};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${ERP_DASHBOARD_FQDN} ${FACTORY_HOST_IP};

    ssl_certificate ${CERT_DIR}/erp.crt;
    ssl_certificate_key ${CERT_DIR}/erp.key;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    client_max_body_size 100m;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    location /websocket {
        proxy_pass http://odoo-longpolling;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location / {
        proxy_pass http://odoo;
    }
}
EOF

echo "[ODOO_015] Verification syntaxique de la configuration nginx..."
if ! nginx -t 2>&1; then
  echo "[ODOO_015] ERREUR : configuration nginx invalide." >&2
  exit 1
fi

# CORRIGE le 2026-09-01 (echec reel decouvert en ODOO_019, voir
# docs/JOURNAL_TECHNIQUE.md) : SELinux (Enforcing par defaut sur Oracle
# Linux 8) bloque par principe toute connexion sortante d'un processus au
# contexte "httpd_t" (nginx) vers un port applicatif comme 8069 - erreur
# reelle observee dans /var/log/nginx/error.log : "connect() ... failed
# (13: Permission denied)". "httpd_can_network_connect" est le booleen
# SELinux officiel exactement prevu pour ce cas d'usage legitime (reverse
# proxy) - jamais un contournement, la solution documentee standard
# RHEL/OL pour un nginx qui proxifie vers une application locale.
echo "[ODOO_015] Autorisation SELinux du reverse-proxy (httpd_can_network_connect)..."
setsebool -P httpd_can_network_connect on

systemctl enable nginx 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
if ! wait_for_service_active nginx 30 5; then
  echo "[ODOO_015] ERREUR : nginx n'a pas demarre." >&2
  exit 1
fi

echo "[ODOO_015] Ouverture du pare-feu (80/443) si firewalld actif..."
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http --add-service=https >/dev/null
  firewall-cmd --reload >/dev/null
fi

# CORRIGE le 2026-09-01 : "nginx a demarre" ne prouve pas que le proxy
# fonctionne reellement (SELinux peut bloquer la connexion sortante sans
# jamais empecher nginx lui-meme de demarrer). Requete HTTPS reelle a
# travers nginx, jusqu'a Odoo et retour, avant de declarer OK - meme
# discipline que les incidents precedents : un service actif n'est pas
# une preuve de fonctionnement de bout en bout.
echo "[ODOO_015] Verification reelle : requete HTTPS a travers le reverse-proxy jusqu'a Odoo..."
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1/web/login" -H "Host: ${ERP_DASHBOARD_FQDN}")
if [ "$HTTP_CODE" != "200" ]; then
  echo "[ODOO_015] ERREUR : le reverse-proxy ne joint pas Odoo (HTTP ${HTTP_CODE}). Voir /var/log/nginx/error.log." >&2
  exit 1
fi

echo "[ODOO_015] OK (https://${ERP_DASHBOARD_FQDN}/)."
exit 0
