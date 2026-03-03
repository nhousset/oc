#!/bin/bash

# ==============================================================================
# Script d'installation des plug-ins SAS Viya CLI
# Copyright (c) 2026 Nicolas Housset
#
# Ce logiciel est distribué sous licence MIT (Open Source).
# Il est fourni "tel quel", sans garantie d'aucune sorte. Vous êtes libre 
# de l'utiliser, le copier, le modifier et le redistribuer sous réserve 
# d'inclure cet avis de droit d'auteur.
# ==============================================================================

# Liste de tous les plug-ins à installer
PLUGINS="audit authorization batch cas common-analytics compute configuration credentials dagentsrv dcmtransfer decisiongitdeploy detection detection-definition detection-message-schema folders fonts identities job launcher licenses listdata migrationmanagement mip-migration models notifications oauth reports rfc-solution-config rtdmobjectmigration scoreexecution sid-functions transfer visual-forecasting workload-orchestrator"

echo "=== Démarrage de l'installation des plugins SAS Viya ==="

# 1. Vérification de l'exécutable local et affichage de la version
if [ -x "./sas-viya" ]; then
    echo "Exécutable local trouvé. Version installée :"
    ./sas-viya -v
else
    echo "❌ Erreur : ./sas-viya est introuvable ou n'est pas exécutable dans ce dossier."
    echo "Assure-toi d'être dans le bon répertoire (actuellement : $(pwd))."
    exit 1
fi

echo "-------------------------------------------------------"

# 2. Boucle d'installation pour chaque plugin
for plugin in $PLUGINS; do
    echo -n "Installation du plugin '$plugin'... "
    
    # Lancement de l'installation en silencieux
    ./sas-viya plugins install --repo SAS "$plugin" > /dev/null 2>&1
    
    # Vérification du code de retour
    if [ $? -eq 0 ]; then
        echo "✅ OK"
    else
        echo "❌ ERREUR"
    fi
done

echo "-------------------------------------------------------"
echo "=== Fin des installations ==="
