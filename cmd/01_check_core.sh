#!/bin/bash
# TITLE: Vérification Core Services (Status)

# Note: La variable $OC_CMD est héritée de oc.sh

echo "🔍 Analyse des services Core Viya..."

# Liste des labels ou noms à surveiller (exemples courants Viya)
TARGETS="sas-consul-server sas-rabbitmq-server sas-logon sas-crunchy-data-postgres"

echo "| POD NAME                       | STATUS   | RESTARTS |"
echo "|--------------------------------|----------|----------|"

# On cherche les pods qui ne sont PAS en Running ou Completed
# On utilise --no-headers pour faciliter le parsing si besoin
$OC_CMD get pods | grep -E "consul|rabbitmq|postgres|logon" | grep -v "Running" | grep -v "Completed" | awk '{printf "| %-30s | %-8s | %-8s |\n", $1, $3, $4}'

# Si la commande précédente ne retourne rien, c'est bon signe
if [ ${PIPESTATUS[2]} -ne 0 ]; then
    echo "| (Tous les services Core semblent OK)      |"
fi
echo "--------------------------------------------"
echo "Résumé global des pods en erreur dans le namespace :"
$OC_CMD get pods --field-selector=status.phase!=Running,status.phase!=Succeeded
