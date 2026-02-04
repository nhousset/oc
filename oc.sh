#!/bin/bash

# ==============================================================================
# CONFIGURATION ET UTILITAIRES
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
CMD_DIR="$SCRIPT_DIR/cmd"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur : Fichier $CONFIG_FILE introuvable."
    exit 1
fi

# -- Fonctions de config (Lecture/Ecriture) --
get_config() {
    key=$1
    grep "^$key" "$CONFIG_FILE" | head -n 1 | cut -d '=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

update_config_key() {
    key=$1
    value=$2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^$key[[:space:]]*=.*|$key = $value|" "$CONFIG_FILE"
    else
        sed -i "s|^$key[[:space:]]*=.*|$key = $value|" "$CONFIG_FILE"
    fi
}

# Chargement de la config
SERVER_URL=$(get_config "SERVER_URL")
TOKEN=$(get_config "TOKEN")
NAMESPACE=$(get_config "DEFAULT_NAMESPACE")
SKIP_TLS=$(get_config "INSECURE_SKIP_TLS_VERIFY")
OC_PATH=$(get_config "OC_EXECUTABLE_PATH")

# Définition de la commande OC (exportée pour les sous-scripts)
if [ -z "$OC_PATH" ]; then
    export OC_CMD="oc"
else
    export OC_CMD="$OC_PATH"
fi

# Options TLS
TLS_OPTIONS=""
if [ "$SKIP_TLS" == "true" ]; then
    TLS_OPTIONS="--insecure-skip-tls-verify=true"
fi

# ==============================================================================
# LOGIQUE DE CONNEXION (Héritée et nettoyée)
# ==============================================================================

ensure_config_exists() {
    local updated=0
    if [ -z "$SERVER_URL" ]; then
        echo "⚠️  URL manquante."
        read -p "👉 URL du cluster : " SERVER_URL
        update_config_key "SERVER_URL" "$SERVER_URL"
        updated=1
    fi
    if [ -z "$TOKEN" ]; then
        echo "⚠️  Token manquant."
        read -p "👉 Token : " TOKEN
        update_config_key "TOKEN" "$TOKEN"
        updated=1
    fi
    if [ -z "$NAMESPACE" ]; then
        echo "⚠️  Namespace par défaut non défini."
        read -p "👉 Namespace (Entrée pour ignorer) : " INPUT_NS
        if [ ! -z "$INPUT_NS" ]; then
            update_config_key "DEFAULT_NAMESPACE" "$INPUT_NS"
            NAMESPACE="$INPUT_NS"
        fi
    fi
}

check_session() {
    # Vérifie si on est déjà connecté
    "$OC_CMD" whoami > /dev/null 2>&1
    return $?
}

do_login() {
    ensure_config_exists

    # Si déjà connecté et que c'est le bon serveur, on ne fait rien (optimisation)
    if check_session; then
        # On pourrait ajouter une vérification de l'URL serveur ici pour être puriste
        echo "✅ Déjà connecté."
        switch_namespace
        return
    fi

    echo "🔌 Connexion à $SERVER_URL..."
    "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Connexion réussie."
        switch_namespace
    else
        echo "❌ Échec de la connexion (Token expiré ?)."
        read -p "👉 Nouveau Token : " NEW_TOKEN
        if [ -z "$NEW_TOKEN" ]; then exit 1; fi

        update_config_key "TOKEN" "$NEW_TOKEN"
        TOKEN="$NEW_TOKEN"

        "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS
        if [ $? -eq 0 ]; then
            echo "✅ Connexion réussie."
            switch_namespace
        else
            echo "❌ Échec critique."
            exit 1
        fi
    fi
}

switch_namespace() {
    if [ ! -z "$NAMESPACE" ]; then
        # Vérifie si on est déjà sur le bon namespace pour éviter le spam
        CURRENT_NS=$("$OC_CMD" project -q 2>/dev/null)
        if [ "$CURRENT_NS" != "$NAMESPACE" ]; then
            echo "📂 Activation du namespace : $NAMESPACE"
            "$OC_CMD" project "$NAMESPACE" > /dev/null
        fi
    fi
}

do_logout() {
    echo "👋 Déconnexion..."
    "$OC_CMD" logout
}

# ==============================================================================
# MENU DYNAMIQUE (Moteur de plugins)
# ==============================================================================

show_menu() {
    # On s'assure d'être connecté avant d'afficher le menu
    do_login 
    
    echo ""
    echo "=========================================="
    echo "   MENU VIYA 4 OPS  (Namespace: $NAMESPACE)"
    echo "=========================================="

    # Création d'un tableau pour stocker les fichiers
    if [ ! -d "$CMD_DIR" ]; then
        echo "❌ Le dossier $CMD_DIR n'existe pas."
        exit 1
    fi

    files=("$CMD_DIR"/*.sh)
    if [ ! -e "${files[0]}" ]; then
        echo "   (Aucun script trouvé dans cmd/)"
        exit 0
    fi

    i=1
    for f in "${files[@]}"; do
        # Extraction du titre via grep. Format attendu: # TITLE: Mon Titre
        TITLE=$(grep "# TITLE:" "$f" | sed 's/# TITLE://' | sed 's/^[[:space:]]*//')
        if [ -z "$TITLE" ]; then TITLE=$(basename "$f"); fi
        echo " $i) $TITLE"
        ((i++))
    done
    echo " q) Quitter & Logout"
    echo " x) Quitter (Garder session)"
    echo "=========================================="
    read -p "Votre choix ? " CHOICE

    if [[ "$CHOICE" == "q" ]]; then
        do_logout
        exit 0
    elif [[ "$CHOICE" == "x" ]]; then
        echo "Bye."
        exit 0
    fi

    # Validation numérique
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -ge $i ]; then
        echo "❌ Choix invalide."
        show_menu # Récursion pour réafficher
        return
    fi

    # Exécution du script choisi
    SELECTED_SCRIPT="${files[$((CHOICE-1))]}"
    
    echo ""
    echo "🚀 Lancement de : $(basename "$SELECTED_SCRIPT")"
    echo "------------------------------------------"
    
    # On rend exécutable à la volée au cas où
    chmod +x "$SELECTED_SCRIPT"
    # On exécute le script
    "$SELECTED_SCRIPT"
    
    echo "------------------------------------------"
    read -p "Appuyez sur Entrée pour revenir au menu..."
    show_menu
}

# ==============================================================================
# MAIN
# ==============================================================================

case "$1" in
    login)
        do_login
        ;;
    logout)
        do_logout
        ;;
    menu|*)
        # Par défaut, on lance le menu
        show_menu
        ;;
esac
