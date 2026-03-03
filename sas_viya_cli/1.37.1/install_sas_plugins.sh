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

echo "====================================================="
echo "   Installation des plug-ins SAS Viya CLI"
echo "====================================================="
echo ""

# 1. Demander le chemin vers sas-viya
read -p "Veuillez indiquer le chemin complet vers le dossier contenant 'sas-viya' (ex: /opt/sas/viya/home/bin) : " SAS_VIYA_DIR

# Correction si l'utilisateur a pointé directement vers le fichier au lieu du dossier
if [[ -f "$SAS_VIYA_DIR" && "$SAS_VIYA_DIR" == *"sas-viya" ]]; then
    SAS_VIYA_DIR=$(dirname "$SAS_VIYA_DIR")
fi

# 2. Vérifier que l'exécutable existe bien à cet endroit
if [ ! -x "$SAS_VIYA_DIR/sas-viya" ]; then
    echo "❌ Erreur : L'exécutable 'sas-viya' est introuvable ou n'a pas les droits d'exécution dans le dossier : $SAS_VIYA_DIR"
    exit 1
fi

# 3. Vérifier si sas-viya est déjà dans le PATH, sinon l'ajouter
if ! command -v sas-viya &> /dev/null; then
    echo "⚠️  'sas-viya' n'est pas détecté dans votre variable PATH."
    echo "👉 Ajout temporaire au PATH pour cette session..."
    export PATH="$SAS_VIYA_DIR:$PATH"
    
    echo ""
    echo "💡 Astuce : Pour l'ajouter de façon permanente à votre système, exécutez cette commande plus tard :"
    echo "   echo 'export PATH=\"$SAS_VIYA_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    echo ""
else
    echo "✅ 'sas-viya'
