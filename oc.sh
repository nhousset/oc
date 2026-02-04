#!/bin/bash

# ==============================================================================
# CONFIGURATION ET UTILITAIRES
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur : Fichier $CONFIG_FILE introuvable."
    exit 1
fi

# -- Fonction de lecture d'une clé --
get_config() {
    key=$1
    grep "^$key" "$CONFIG_FILE" | head -n 1 | cut -d '=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# -- Fonction de mise à jour générique --
update_config_key() {
    key=$1
    value=$2
    # Utilisation de | comme séparateur pour éviter les conflits avec les / des URLs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^$key[[:space:]]*=.*|$key = $value|" "$CONFIG_FILE"
    else
        sed -i "s|^$key[[:space:]]*=.*|$key = $value|" "$CONFIG_FILE"
    fi
}

# Lecture de la config initiale
SERVER_URL=$(get_config "SERVER_URL")
TOKEN=$(get_config "TOKEN")
NAMESPACE=$(get_config "DEFAULT_NAMESPACE")
SKIP_TLS=$(get_config "INSECURE_SKIP_TLS_VERIFY")
OC_PATH=$(get_config "OC_EXECUTABLE_PATH")

# Définition de l'exécutable
if [ -z "$OC_PATH" ]; then
    OC_CMD="oc"
else
    OC_CMD="$OC_PATH"
fi

# Options TLS
TLS_OPTIONS=""
if [ "$SKIP_TLS" == "true" ]; then
    TLS_OPTIONS="--insecure-skip-tls-verify=true"
fi

# ==============================================================================
# LOGIQUE
# ==============================================================================

# Vérifie et demande les infos manquantes (URL, Token, Namespace)
ensure_config_exists() {
    local updated=0

    # 1. Vérification de l'URL
    if [ -z "$SERVER_URL" ]; then
        echo "⚠️  L'URL du serveur est manquante dans config.ini."
        echo -n "👉 Veuillez saisir l'URL du cluster (ex: https://api.cluster...:6443) : "
        read -r SERVER_URL
        if [ -z "$SERVER_URL" ]; then echo "❌ URL obligatoire."; exit 1; fi
        update_config_key "SERVER_URL" "$SERVER_URL"
        updated=1
    fi

    # 2. Vérification du Token
    if [ -z "$TOKEN" ]; then
        if [ $updated -eq 1 ]; then echo ""; fi
        echo "⚠️  Le Token est manquant dans config.ini."
        echo -n "👉 Veuillez saisir votre Token (ex: sha256~...) : "
        read -r TOKEN
        if [ -z "$TOKEN" ]; then echo "❌ Token obligatoire."; exit 1; fi
        update_config_key "TOKEN" "$TOKEN"
        updated=1
    fi

    # 3. Vérification du Namespace
    if [ -z "$NAMESPACE" ]; then
        if [ $updated -eq 1 ]; then echo ""; fi
        echo "⚠️  Le Namespace par défaut n'est pas défini."
        echo -n "👉 Entrez le namespace (ou Appuyez sur Entrée pour ignorer) : "
        read -r INPUT_NS
        
        if [ ! -z "$INPUT_NS" ]; then
            # Si l'utilisateur a saisi quelque chose, on sauvegarde et on met à jour la variable
            update_config_key "DEFAULT_NAMESPACE" "$INPUT_NS"
            NAMESPACE="$INPUT_NS"
        else
            echo "   Aucun namespace défini pour cette session."
        fi
    fi
}

do_login() {
    # On s'assure d'abord d'avoir toutes les infos
    ensure_config_exists

    echo "🔌 Connexion à $SERVER_URL..."
    
    # Tentative de connexion silencieuse
    "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Connexion réussie."
        switch_namespace
    else
        echo "❌ Échec de la connexion (Token expiré ou invalide)."
        echo "👉 Veuillez saisir un NOUVEAU token :"
        read -r NEW_TOKEN

        if [ -z "$NEW_TOKEN" ]; then
            echo "   Annulé."
            exit 1
        fi

        # Mise à jour et nouvelle tentative
        update_config_key "TOKEN" "$NEW_TOKEN"
        TOKEN="$NEW_TOKEN"

        echo "🔄 Nouvelle tentative..."
        "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS
        
        if [ $? -eq 0 ]; then
            echo "✅ Connexion réussie et config.ini mis à jour."
            switch_namespace
        else
            echo "❌ Erreur fatale. Vérifiez l'URL ou vos droits d'accès."
            exit 1
        fi
    fi
}

switch_namespace() {
    if [ ! -z "$NAMESPACE" ]; then
        echo "📂 Activation du namespace : $NAMESPACE"
        "$OC_CMD" project "$NAMESPACE"
    fi
}

do_logout() {
    echo "👋 Déconnexion..."
    "$OC_CMD" logout
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
    *)
        echo "Usage: $0 {login|logout}"
        exit 1
        ;;
esac
