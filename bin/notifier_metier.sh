#!/bin/bash
# notifier_metier.sh - Alerte par email sur EVENEMENT METIER, ajoute le
# 2026-09-05 (demande explicite utilisateur, a la maniere de
# bin/notifier.sh/WAZ_ELK_FACTORY, adapte au contexte ERP_CRM_FACTORY).
#
# DIFFERENT de bin/notifier.sh : celui-ci alerte l'EXPLOITANT IT quand
# un JOB ECHOUE (evenement systeme). Celui-ci alerte un DESTINATAIRE
# METIER (RH, commercial, atelier, marketing...) quand un traitement a
# REUSSI et produit un resultat qui merite un regard humain - le
# fichier reellement genere dans $OPERATIONS_DIR/<module>/snd (ou recu
# dans rcv) est joint TEL QUEL, jamais recopie/reformate. Le CRITERE
# de declenchement (typiquement "au moins 1 ligne exploitable") est
# decide par le job appelant, jamais ici - ce script se contente
# d'envoyer ce qu'on lui donne, jamais un envoi systematique a chaque
# execution reussie.
#
# Meme mecanisme SMTP que bin/notifier.sh (curl en SMTP direct, meme
# detection SSL/STARTTLS, meme secret SMTP_PASS_FILE hors de Git) -
# reutilise le meme compte (SMTP_HOST/PORT/USER/PASS_FILE, vars.conf),
# seul le toggle (NOTIF_METIER_ENABLED) et le destinataire
# (NOTIF_METIER_TO) sont distincts de NOTIF_ENABLED/NOTIF_TO.
#
# Usage :
#   ./notifier_metier.sh --test
#     -> envoie un email de test avec une piece jointe factice, pour
#        valider la configuration independamment de tout job reel.
#   ./notifier_metier.sh "<SUJET>" "<CORPS>" [PIECE_JOINTE...]
#     -> appele depuis un job (voir jobs/ECFCALRRH1.sh pour un exemple
#        reel) une fois son propre critere metier verifie. 0 ou
#        plusieurs pieces jointes (chemins de fichiers REELLEMENT
#        produits/recus par ce job, jamais un fichier invente).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"

# Desactive par defaut (voir vars.conf) : aucun envoi tant que ce n'est
# pas explicitement configure - meme discipline que NOTIF_ENABLED.
if [ "${NOTIF_METIER_ENABLED:-non}" != "oui" ]; then
  echo "[notifier_metier] NOTIF_METIER_ENABLED != oui dans vars.conf - aucun email metier envoye (normal si non configure)."
  exit 0
fi

MANQUANT=""
[ -z "${SMTP_HOST:-}" ] && MANQUANT="${MANQUANT}SMTP_HOST "
[ -z "${SMTP_USER:-}" ] && MANQUANT="${MANQUANT}SMTP_USER "
[ -z "${SMTP_PASS_FILE:-}" ] && MANQUANT="${MANQUANT}SMTP_PASS_FILE "
[ -z "${NOTIF_FROM:-}" ] && MANQUANT="${MANQUANT}NOTIF_FROM "
[ -z "${NOTIF_METIER_TO:-}" ] && MANQUANT="${MANQUANT}NOTIF_METIER_TO "
if [ -n "$MANQUANT" ]; then
  echo "[notifier_metier] ERREUR : NOTIF_METIER_ENABLED=oui mais variable(s) manquante(s) dans vars.conf : $MANQUANT"
  exit 1
fi
if [ ! -f "$SMTP_PASS_FILE" ]; then
  echo "[notifier_metier] ERREUR : SMTP_PASS_FILE ($SMTP_PASS_FILE) introuvable."
  echo "Creez-le : echo 'mot_de_passe' > $SMTP_PASS_FILE && chmod 600 $SMTP_PASS_FILE"
  exit 1
fi
SMTP_PASS="$(cat "$SMTP_PASS_FILE")"

# Construit un email multipart/mixed (corps texte + 0..N pieces
# jointes en base64) - contrairement a bin/notifier.sh (texte seul),
# c'est justement la piece jointe qui repond a la demande "voir les
# elements generes dans les repertoires, arrives par mail".
send_mail_metier(){
  local subject="$1"
  local body="$2"
  shift 2
  local pieces=("$@")
  local tmp_mail boundary
  tmp_mail=$(mktemp)
  boundary="ECF-$(date +%s)-$$"

  {
    echo "From: ${NOTIF_FROM}"
    echo "To: ${NOTIF_METIER_TO}"
    echo "Subject: ${subject}"
    echo "Date: $(date -R)"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"${boundary}\""
    echo ""
    echo "--${boundary}"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo ""
    echo "$body"
    for f in "${pieces[@]}"; do
      [ -f "$f" ] || { echo "[notifier_metier] ATTENTION : piece jointe introuvable, ignoree : $f" >&2; continue; }
      echo ""
      echo "--${boundary}"
      echo "Content-Type: application/octet-stream; name=\"$(basename "$f")\""
      echo "Content-Transfer-Encoding: base64"
      echo "Content-Disposition: attachment; filename=\"$(basename "$f")\""
      echo ""
      base64 -w 76 "$f"
    done
    echo ""
    echo "--${boundary}--"
  } > "$tmp_mail"

  # Meme detection SSL (465) / STARTTLS (587, ou SMTP_TLS_MODE force)
  # que bin/notifier.sh - voir ce fichier pour le detail du choix.
  local tls_mode="${SMTP_TLS_MODE:-}"
  if [ -z "$tls_mode" ]; then
    if [ "${SMTP_PORT}" = "465" ]; then tls_mode="ssl"; else tls_mode="starttls"; fi
  fi
  local scheme="smtp"
  [ "$tls_mode" = "ssl" ] && scheme="smtps"

  curl -s -S --url "${scheme}://${SMTP_HOST}:${SMTP_PORT}" \
    --mail-from "${NOTIF_FROM}" \
    --mail-rcpt "${NOTIF_METIER_TO}" \
    --user "${SMTP_USER}:${SMTP_PASS}" \
    --upload-file "$tmp_mail" \
    --ssl-reqd
  local rc=$?
  rm -f "$tmp_mail"
  return $rc
}

if [ "${1:-}" = "--test" ]; then
  TMP_PIECE="$(mktemp --suffix=.txt)"
  echo "Exemple de piece jointe generee par un traitement ECF." > "$TMP_PIECE"
  echo "[notifier_metier] Envoi d'un email de test (avec piece jointe) a ${NOTIF_METIER_TO} via ${SMTP_HOST}:${SMTP_PORT}..."
  if send_mail_metier "[${PROJECT_NAME:-ERP_CRM_FACTORY}] Test notification metier" \
    "Ceci est un email de test envoye par notifier_metier.sh --test le $(date -Iseconds).
Si vous recevez ceci AVEC la piece jointe, la configuration (vars.conf, NOTIF_METIER_*) est correcte." \
    "$TMP_PIECE"; then
    echo "[notifier_metier] Email de test envoye avec succes."
    rm -f "$TMP_PIECE"
    exit 0
  else
    echo "[notifier_metier] ECHEC de l'envoi. Verifiez SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS_FILE/NOTIF_METIER_TO."
    rm -f "$TMP_PIECE"
    exit 1
  fi
fi

SUBJECT="${1:-}"
BODY="${2:-}"
if [ -z "$SUBJECT" ] || [ -z "$BODY" ]; then
  echo "Usage : ./notifier_metier.sh --test"
  echo "        ./notifier_metier.sh \"<SUJET>\" \"<CORPS>\" [PIECE_JOINTE...]"
  exit 1
fi
shift 2 || true

echo "[notifier_metier] Envoi de l'email metier : ${SUBJECT}..."
if send_mail_metier "[${PROJECT_NAME:-ERP_CRM_FACTORY}] ${SUBJECT}" "$BODY" "$@"; then
  echo "[notifier_metier] Email metier envoye."
  exit 0
else
  echo "[notifier_metier] ECHEC de l'envoi de l'email metier (mais ne bloque jamais le job appelant)."
  exit 1
fi
