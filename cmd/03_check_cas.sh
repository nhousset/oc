#!/bin/bash
# TITLE: État du CAS Server

echo "🔍 Vérification du CAS Controller et Workers..."

$OC_CMD get pods -l app.kubernetes.io/managed-by=sas-cas-operator -o wide
