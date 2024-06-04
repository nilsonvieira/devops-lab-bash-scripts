#!/bin/bash

mDIREC=/Users/nilson/Workspace/Pulse/DevOps/cd-files/master/engenharia

# Busca pelos diretórios que contêm o arquivo external-secrets.yaml
directories=$(find $mDIREC -name "external-secrets.yaml" -exec dirname {} \;)

# Loop para percorrer cada diretório encontrado e remover os arquivos desejados
for dir in $directories; do
    # Verifica se o arquivo secret.yaml existe e o remove
    if [ -f "$dir/secret.yaml" ]; then
        rm "$dir/secret.yaml"
        echo "Removed $dir/secret.yaml"
    fi
    
    # Verifica se o arquivo configmap.yaml existe e o remove
    if [ -f "$dir/configmap.yaml" ]; then
        rm "$dir/configmap.yaml"
        echo "Removed $dir/configmap.yaml"
    fi
done