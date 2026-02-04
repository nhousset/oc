#!/bin/bash
# TITLE: Vérification Compute Servers

echo "🔍 Analyse des serveurs de calcul (Compute)..."

# Compte combien de pods compute sont actifs
COUNT=$($OC_CMD get pods -l app.kubernetes.io/name=sas-compute -o name | wc -l)

echo "Nombre de sessions Compute actives : $COUNT"

if [ "$COUNT" -gt 0 ]; then
    echo ""
    echo "Détails des sessions :"
    $OC_CMD get pods -l app.kubernetes.io/name=sas-compute -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp,NODE:.spec.nodeName
else
    echo "Aucune session de calcul en cours."
fi

echo ""
echo "Vérification des logs récents (tail) sur le dernier pod compute (si existant)..."
LAST_POD=$($OC_CMD get pods -l app.kubernetes.io/name=sas-compute --sort-by=.metadata.creationTimestamp -o name | tail -n 1)

if [ ! -z "$LAST_POD" ]; then
    echo "Logs partiels de $LAST_POD :"
    $OC_CMD logs "$LAST_POD" --tail=10
fi
