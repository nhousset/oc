#!/bin/bash

# ==============================================================================
# CONFIGURATION ET UTILITAIRES
# ==============================================================================

# Chemin vers le fichier config.ini (dans le même dossier que ce script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.ini"

# Vérification de la présence du fichier de configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur : Fichier $CONFIG_FILE introuvable."
    exit 1
fi

# Fonction pour lire une valeur dans config.ini
get_config() {
    key=$1
    grep "^$key" "$CONFIG_FILE" | head -n 1 | cut -d '=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Fonction pour mettre à jour le token dans config.ini
update_token_in_config() {
    new_token=$1
    # Échappement des caractères spéciaux si nécessaire (basique pour sed)
    # On utilise une syntaxe compatible Linux (sed -i) et macOS (sed -i '')
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^TOKEN[[:space:]]*=.*|TOKEN = $new_token|" "$CONFIG_FILE"
    else
        sed -i "s|^TOKEN[[:space:]]*=.*|TOKEN = $new_token|" "$CONFIG_FILE"
    fi
}

# Lecture des configurations initiales
SERVER_URL=$(get_config "SERVER_URL")
TOKEN=$(get_config "TOKEN")
NAMESPACE=$(get_config "DEFAULT_NAMESPACE")
SKIP_TLS=$(get_config "INSECURE_SKIP_TLS_VERIFY")
OC_PATH=$(get_config "OC_EXECUTABLE_PATH")

# Détermination de la commande oc
if [ -z "$OC_PATH" ]; then
    OC_CMD="oc"
else
    OC_CMD="$OC_PATH"
fi

# Options de sécurité
TLS_OPTIONS=""
if [ "$SKIP_TLS" == "true" ]; then
    TLS_OPTIONS="--insecure-skip-tls-verify=true"
fi

# ==============================================================================
# LOGIQUE PRINCIPALE
# ==============================================================================

do_login() {
    echo " Tentative de connexion à $SERVER_URL..."
    
    # Première tentative de connexion
    # On capture la sortie d'erreur pour ne pas polluer l'écran si on gère l'erreur nous-mêmes,
    # ou on laisse passer pour que l'utilisateur voit pourquoi ça échoue.
    "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Connexion réussie avec le token actuel."
        switch_namespace
    else
        echo "❌ Échec de la connexion (Token expiré ou invalide)."
        echo "   Veuillez entrer un nouveau token."
        echo -n "   Nouveau Token : "
        read -r NEW_TOKEN

        if [ -z "$NEW_TOKEN" ]; then
            echo "   Aucun token saisi. Abandon."
            exit 1
        fi

        echo "   Mise à jour de config.ini..."
        update_token_in_config "$NEW_TOKEN"
        
        # Mise à jour de la variable pour la commande suivante
        TOKEN="$NEW_TOKEN"

        echo "   Nouvelle tentative de connexion..."
        "$OC_CMD" login "$SERVER_URL" --token="$TOKEN" $TLS_OPTIONS
        
        if [ $? -eq 0 ]; then
            echo "✅ Connexion réussie et token sauvegardé."
            switch_namespace
        else
            echo "❌ Toujours impossible de se connecter. Vérifiez l'URL ou le token."
            exit 1
        fi
    fi
}

switch_namespace() {
    if [ ! -z "$NAMESPACE" ]; then
        echo "👉 Activation du namespace : $NAMESPACE"
        "$OC_CMD" project "$NAMESPACE"
    fi
}

do_logout() {
    echo "Déconnexion..."
    "$OC_CMD" logout
}

# ==============================================================================
# POINT D'ENTRÉE
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
        echo "Exemple:"
        echo "  $0 login   -> Connecte (et demande le token si expiré)"
        echo "  $0 logout  -> Déconnecte"
        exit 1
        ;;
esac
