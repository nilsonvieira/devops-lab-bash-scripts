#!/bin/bash

ORG="gmservice"            
PROJECT="GMS-ERP" 
PAT="TOKEN"                
FILTERS=("mfe" "angular")           

ENCODED_PAT=$(echo -n ":$PAT" | base64)

REPOS_JSON=$(curl -s -H "Authorization: Basic $ENCODED_PAT" \
    "https://dev.azure.com/$ORG/$PROJECT/_apis/git/repositories?api-version=7.0")

RESULTS=()

for filter in "${FILTERS[@]}"; do
    echo "🔍 Buscando repositórios com: '$filter'"
    while read -r repo; do
        RESULTS+=("$repo")
    done < <(echo "$REPOS_JSON" | jq -r --arg filter "$filter" '.value[] | select(.name | test($filter; "i")) | .name')
done

echo -e "\n Repositórios encontrados:"
echo -e "\n -------------------------"
printf "%s\n" "${RESULTS[@]}" | sort -u