#!/bin/bash

ORGANIZATION="gmservice"
PROJECT="GMS-ERP"
PAT="TOKEN" 
API_BASE_URL="https://dev.azure.com/$ORGANIZATION/$PROJECT/_apis"

REPO_FILTER="$1"
DISABLE_MODE="false"

if [[ "$2" == "--disable-policy" ]] || [[ "$1" == "--disable-policy" && -n "$2" ]]; then
    DISABLE_MODE="true"
    if [[ "$1" == "--disable-policy" ]]; then
        REPO_FILTER="$2"
    fi
fi

show_help() {
    echo -e "${GREEN}=== Azure DevOps Build Policy Configuration Script ===${NC}"
    echo -e "${BLUE}Uso:${NC}"
    echo -e "  $0 [FILTRO_REPOSITORIO] [--disable-policy]"
    echo ""
    echo -e "${BLUE}Exemplos:${NC}"
    echo -e "  $0 mfe                      # Aplica policies nos repos que contêm 'mfe'"
    echo -e "  $0 devops-poc-teste         # Aplica policies nos repos que contêm 'devops-poc-teste'"
    echo -e "  $0 produto-consulta         # Aplica policies no repo específico"
    echo -e "  $0 mfe --disable-policy     # REMOVE policies dos repos que contêm 'mfe'"
    echo -e "  $0 --disable-policy mfe     # REMOVE policies dos repos que contêm 'mfe'"
    echo ""
    echo -e "${BLUE}Parâmetros:${NC}"
    echo -e "  --disable-policy            # Remove todas as build policies (não aplica novas)"
    echo ""
    echo -e "${BLUE}Descrição:${NC}"
    echo -e "  Configura build policies nas branches develop/main/master"
    echo -e "  dos repositórios que correspondem ao filtro especificado."
    echo -e "  Com --disable-policy, apenas REMOVE as policies existentes."
    echo ""
    echo -e "${BLUE}Configurações aplicadas (modo normal):${NC}"
    echo -e "  • Policy: Habilitada e opcional"
    echo -e "  • Trigger: Automático (quando branch é atualizada)"
    echo -e "  • Expiração: Imediatamente quando branch é atualizada"
    echo ""
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

api_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    
    if [ "$method" = "GET" ]; then
        curl -s -u ":$PAT" "$url"
    elif [ "$method" = "POST" ]; then
        curl -s -u ":$PAT" -X POST -H "Content-Type: application/json" -d "$data" "$url"
    elif [ "$method" = "PUT" ]; then
        curl -s -u ":$PAT" -X PUT -H "Content-Type: application/json" -d "$data" "$url"
    fi
}

get_build_definition_id() {
    local repo_name="$1"
    local definitions_url="$API_BASE_URL/build/definitions?api-version=7.0&name=$repo_name*"
    
    echo -e "${BLUE}Buscando build definition para: $repo_name${NC}" >&2
    local response=$(api_request "GET" "$definitions_url")
    
    local definition_id=$(echo "$response" | jq -r --arg repo "$repo_name" '.value[] | select(.name | contains($repo)) | .id' | head -n1)
    
    if [ "$definition_id" != "null" ] && [ -n "$definition_id" ]; then
        echo -e "${GREEN}Build definition encontrada: ID $definition_id${NC}" >&2
        echo "$definition_id"
    else
        echo -e "${YELLOW}Nenhuma build definition encontrada para $repo_name${NC}" >&2
        echo ""
    fi
}

get_branches() {
    local repo_id="$1"
    local branches_url="$API_BASE_URL/git/repositories/$repo_id/refs?filter=heads&api-version=7.0"
    
    local response=$(api_request "GET" "$branches_url")
    echo "$response" | jq -r '.value[] | .name' | sed 's|refs/heads/||'
}

remove_build_policies() {
    local repo_name="$1"
    local repo_id="$2"
    
    echo -e "\n${RED}===========================================${NC}"
    echo -e "${RED}REMOVENDO POLICIES: $repo_name${NC}"
    echo -e "${RED}===========================================${NC}"
    
    echo -e "${BLUE}Buscando build definition para: $repo_name${NC}"
    local build_definition_id=$(get_build_definition_id "$repo_name")
    
    if [ -z "$build_definition_id" ]; then
        echo -e "${YELLOW}Pulando $repo_name - Nenhuma build definition encontrada${NC}"
        return
    fi
    
    echo -e "${RED}Removendo TODAS as build policies para build definition $build_definition_id...${NC}"
    local all_policies_url="$API_BASE_URL/policy/configurations?api-version=7.0"
    local all_policies=$(api_request "GET" "$all_policies_url")
    
    local policies_to_remove=$(echo "$all_policies" | jq --arg build_id "$build_definition_id" '
        [.value[] | 
         select(.type.id == "0609b952-1397-4640-95ec-e00a01b2c241") |
         select(.settings.buildDefinitionId == ($build_id | tonumber))]
    ')
    
    local remove_count=$(echo "$policies_to_remove" | jq 'length')
    echo -e "${YELLOW}Encontradas $remove_count policies para remoção${NC}"
    
    if [ "$remove_count" -gt 0 ]; then
        echo -e "${RED}Policies que serão REMOVIDAS:${NC}"
        echo "$policies_to_remove" | jq -r '.[] | "ID: \(.id) - Nome: \(.displayName // "Sem nome")"'
        
        local policy_ids=$(echo "$policies_to_remove" | jq -r '.[] | .id')
        local removed_count=0
        
        while IFS= read -r policy_id; do
            if [ -n "$policy_id" ] && [ "$policy_id" != "null" ]; then
                echo -e "${YELLOW}Removendo policy ID: $policy_id${NC}"
                local delete_url="$API_BASE_URL/policy/configurations/$policy_id?api-version=7.0"
                
                local delete_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -u ":$PAT" -X DELETE "$delete_url")
                local http_code=$(echo "$delete_response" | grep "HTTPSTATUS:" | cut -d: -f2)
                
                if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
                    echo -e "${GREEN}✓ Policy ID $policy_id REMOVIDA${NC}"
                    ((removed_count++))
                else
                    echo -e "${RED}✗ Erro ao remover policy ID $policy_id (HTTP $http_code)${NC}"
                fi
            fi
        done <<< "$policy_ids"
        
        echo -e "${GREEN}TOTAL REMOVIDAS: $removed_count de $remove_count${NC}"
    else
        echo -e "${BLUE}Nenhuma policy encontrada para remoção.${NC}"
    fi
    
    echo -e "${RED}Remoção de policies do repositório $repo_name concluída!${NC}"
}

create_build_policy_simple() {
    local repo_id="$1"
    local branch_name="$2"
    local build_definition_id="$3"
    local repo_name="$4"
    
    echo -e "${BLUE}=== CONFIGURANDO BUILD POLICY ===${NC}"
    echo -e "${BLUE}Repositório: $repo_name${NC}"
    echo -e "${BLUE}Branch: $branch_name${NC}"
    echo -e "${BLUE}Repo ID: $repo_id${NC}"
    echo -e "${BLUE}Build Definition ID: $build_definition_id${NC}"
    
    echo -e "${YELLOW}REMOVENDO TODAS as build policies para build definition $build_definition_id...${NC}"
    local all_policies_url="$API_BASE_URL/policy/configurations?api-version=7.0"
    local all_policies=$(api_request "GET" "$all_policies_url")
    
    local policies_to_remove=$(echo "$all_policies" | jq --arg build_id "$build_definition_id" '
        [.value[] | 
         select(.type.id == "0609b952-1397-4640-95ec-e00a01b2c241") |
         select(.settings.buildDefinitionId == ($build_id | tonumber))]
    ')
    
    local remove_count=$(echo "$policies_to_remove" | jq 'length')
    echo -e "${YELLOW}Encontradas $remove_count policies para build definition $build_definition_id${NC}"
    
    if [ "$remove_count" -gt 0 ]; then
        echo -e "${RED}REMOVENDO TODAS as policies desta build definition:${NC}"
        echo "$policies_to_remove" | jq -r '.[] | "ID: \(.id) - Nome: \(.displayName // "Sem nome")"'
        
        local policy_ids=$(echo "$policies_to_remove" | jq -r '.[] | .id')
        local removed_count=0
        
        while IFS= read -r policy_id; do
            if [ -n "$policy_id" ] && [ "$policy_id" != "null" ]; then
                echo -e "${YELLOW}Removendo policy ID: $policy_id${NC}"
                local delete_url="$API_BASE_URL/policy/configurations/$policy_id?api-version=7.0"
                
                local delete_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -u ":$PAT" -X DELETE "$delete_url")
                local http_code=$(echo "$delete_response" | grep "HTTPSTATUS:" | cut -d: -f2)
                
                if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
                    echo -e "${GREEN}✓ Policy ID $policy_id REMOVIDA${NC}"
                    ((removed_count++))
                else
                    echo -e "${RED}✗ Erro ao remover policy ID $policy_id (HTTP $http_code)${NC}"
                fi
            fi
        done <<< "$policy_ids"
        
        echo -e "${GREEN}TOTAL REMOVIDAS: $removed_count de $remove_count${NC}"
        
        if [ $removed_count -gt 0 ]; then
            echo -e "${BLUE}Aguardando 5 segundos para garantir sincronização...${NC}"
            sleep 5
        fi
    fi
    
    local create_json='{
        "isEnabled": true,
        "isBlocking": false,
        "type": {
            "id": "0609b952-1397-4640-95ec-e00a01b2c241"
        },
        "settings": {
            "buildDefinitionId": '$build_definition_id',
            "displayName": "'$repo_name' Build Policy",
            "queueOnSourceUpdateOnly": false,
            "manualQueueOnly": false,
            "validDuration": 0,
            "scope": [
                {
                    "repositoryId": "'$repo_id'",
                    "refName": "refs/heads/'$branch_name'",
                    "matchKind": "exact"
                }
            ]
        }
    }'
    
    echo -e "${BLUE}Criando nova policy para branch: $branch_name${NC}"
    
    local create_json='{
        "isEnabled": true,
        "isBlocking": false,
        "type": {
            "id": "0609b952-1397-4640-95ec-e00a01b2c241"
        },
        "settings": {
            "buildDefinitionId": '$build_definition_id',
            "displayName": "'$repo_name' '$branch_name' Build Policy",
            "queueOnSourceUpdateOnly": false,
            "manualQueueOnly": false,
            "validDuration": 0,
            "scope": [
                {
                    "repositoryId": "'$repo_id'",
                    "refName": "refs/heads/'$branch_name'",
                    "matchKind": "exact"
                }
            ]
        }
    }'
    
    local create_url="$API_BASE_URL/policy/configurations?api-version=7.0"
    
    echo -e "${YELLOW}Criando policy para branch $branch_name...${NC}"
    local response=$(api_request "POST" "$create_url" "$create_json")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        local new_policy_id=$(echo "$response" | jq -r '.id')
        echo -e "${GREEN}✓ Policy criada com sucesso para $branch_name! ID: $new_policy_id${NC}"
    else
        echo -e "${RED}✗ Erro ao criar policy para $branch_name:${NC}"
        echo "$response" | jq '.'
    fi
    
    echo -e "${BLUE}Aguardando 2 segundos antes da próxima operação...${NC}"
    sleep 2
    
    echo -e "${BLUE}=================================${NC}"
}

process_repository() {
    local repo_name="$1"
    local repo_id="$2"
    
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}Processando repositório: $repo_name${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    echo -e "${BLUE}Buscando build definition para: $repo_name${NC}"
    local build_definition_id=$(get_build_definition_id "$repo_name")
    
    if [ -z "$build_definition_id" ]; then
        echo -e "${RED}Pulando $repo_name - Nenhuma build definition encontrada${NC}"
        return
    fi
    
    local branches=$(get_branches "$repo_id")
    
    local target_branches=()
    
    while IFS= read -r branch; do
        if [[ "$branch" == "develop" ]] || [[ "$branch" == "main" ]] || [[ "$branch" == "master" ]]; then
            target_branches+=("$branch")
        fi
    done <<< "$branches"
    
    if [ ${#target_branches[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nenhuma branch alvo (develop/main/master) encontrada em $repo_name${NC}"
        return
    fi
    
    echo -e "${GREEN}Branches encontradas: ${target_branches[*]}${NC}"
    
    echo -e "${YELLOW}REMOVENDO TODAS as build policies para build definition $build_definition_id...${NC}"
    local all_policies_url="$API_BASE_URL/policy/configurations?api-version=7.0"
    local all_policies=$(api_request "GET" "$all_policies_url")
    
    local policies_to_remove=$(echo "$all_policies" | jq --arg build_id "$build_definition_id" '
        [.value[] | 
         select(.type.id == "0609b952-1397-4640-95ec-e00a01b2c241") |
         select(.settings.buildDefinitionId == ($build_id | tonumber))]
    ')
    
    local remove_count=$(echo "$policies_to_remove" | jq 'length')
    echo -e "${YELLOW}Encontradas $remove_count policies para build definition $build_definition_id${NC}"
    
    if [ "$remove_count" -gt 0 ]; then
        echo -e "${RED}REMOVENDO TODAS as policies desta build definition:${NC}"
        echo "$policies_to_remove" | jq -r '.[] | "ID: \(.id) - Nome: \(.displayName // "Sem nome")"'
        
        local policy_ids=$(echo "$policies_to_remove" | jq -r '.[] | .id')
        local removed_count=0
        
        while IFS= read -r policy_id; do
            if [ -n "$policy_id" ] && [ "$policy_id" != "null" ]; then
                echo -e "${YELLOW}Removendo policy ID: $policy_id${NC}"
                local delete_url="$API_BASE_URL/policy/configurations/$policy_id?api-version=7.0"
                
                local delete_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -u ":$PAT" -X DELETE "$delete_url")
                local http_code=$(echo "$delete_response" | grep "HTTPSTATUS:" | cut -d: -f2)
                
                if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
                    echo -e "${GREEN}✓ Policy ID $policy_id REMOVIDA${NC}"
                    ((removed_count++))
                else
                    echo -e "${RED}✗ Erro ao remover policy ID $policy_id (HTTP $http_code)${NC}"
                fi
            fi
        done <<< "$policy_ids"
        
        echo -e "${GREEN}TOTAL REMOVIDAS: $removed_count de $remove_count${NC}"
        
        if [ $removed_count -gt 0 ]; then
            echo -e "${BLUE}Aguardando 5 segundos para garantir sincronização...${NC}"
            sleep 5
        fi
    fi
    
    echo -e "${BLUE}Criando policies para todas as branches: ${target_branches[*]}${NC}"
    
    for branch in "${target_branches[@]}"; do
        echo -e "${BLUE}=== Criando policy para branch: $branch ===${NC}"
        
        local create_json='{
            "isEnabled": true,
            "isBlocking": false,
            "type": {
                "id": "0609b952-1397-4640-95ec-e00a01b2c241"
            },
            "settings": {
                "buildDefinitionId": '$build_definition_id',
                "displayName": "'$repo_name' '$branch' Build Policy",
                "queueOnSourceUpdateOnly": false,
                "manualQueueOnly": false,
                "validDuration": 0,
                "scope": [
                    {
                        "repositoryId": "'$repo_id'",
                        "refName": "refs/heads/'$branch'",
                        "matchKind": "exact"
                    }
                ]
            }
        }'
        
        local create_url="$API_BASE_URL/policy/configurations?api-version=7.0"
        
        echo -e "${YELLOW}Criando policy para branch $branch...${NC}"
        local response=$(api_request "POST" "$create_url" "$create_json")
        
        if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
            local new_policy_id=$(echo "$response" | jq -r '.id')
            echo -e "${GREEN}✓ Policy criada com sucesso para $branch! ID: $new_policy_id${NC}"
        else
            echo -e "${RED}✗ Erro ao criar policy para $branch:${NC}"
            echo "$response" | jq '.'
        fi
        
        echo -e "${BLUE}Aguardando 2 segundos antes da próxima branch...${NC}"
        sleep 2
    done
    
    echo -e "${GREEN}Processamento do repositório $repo_name concluído!${NC}"
}

main() {
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ -z "$1" && "$DISABLE_MODE" == "false" ]]; then
        show_help
        exit 0
    fi
    
    if [[ -z "$REPO_FILTER" ]]; then
        echo -e "${RED}Erro: Filtro de repositório é obrigatório!${NC}"
        show_help
        exit 1
    fi
    
    if [[ "$DISABLE_MODE" == "true" ]]; then
        echo -e "${RED}Iniciando REMOÇÃO de Build Policies${NC}"
        echo -e "${RED}Organização: $ORGANIZATION${NC}"
        echo -e "${RED}Projeto: $PROJECT${NC}"
        echo -e "${RED}Filtro de repositórios: '$REPO_FILTER'${NC}"
        echo -e "${RED}MODO: REMOÇÃO DE POLICIES${NC}"
    else
        echo -e "${GREEN}Iniciando configuração de Build Policies${NC}"
        echo -e "${GREEN}Organização: $ORGANIZATION${NC}"
        echo -e "${GREEN}Projeto: $PROJECT${NC}"
        echo -e "${GREEN}Filtro de repositórios: '$REPO_FILTER'${NC}"
        echo -e "${GREEN}MODO: APLICAÇÃO DE POLICIES${NC}"
    fi
    echo ""
    
    if [ -z "$PAT" ]; then
        echo -e "${RED}ERRO: Personal Access Token (PAT) não configurado!${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERRO: jq não está instalado!${NC}"
        exit 1
    fi
    
    local repos_url="$API_BASE_URL/git/repositories?api-version=7.0"
    echo -e "${BLUE}Buscando repositórios...${NC}"
    
    local repos_response=$(api_request "GET" "$repos_url")
    
    if [ -z "$repos_response" ]; then
        echo -e "${RED}Erro ao buscar repositórios.${NC}"
        exit 1
    fi
    
    local processed_count=0
    local found_count=0
    
    while IFS= read -r line; do
        local repo_name=$(echo "$line" | jq -r '.name')
        local repo_id=$(echo "$line" | jq -r '.id')
        ((found_count++))
        
        if [[ "$repo_name" == *"$REPO_FILTER"* ]]; then
            if [[ "$DISABLE_MODE" == "true" ]]; then
                remove_build_policies "$repo_name" "$repo_id"
            else
                process_repository "$repo_name" "$repo_id"
            fi
            ((processed_count++))
        else
            echo -e "${YELLOW}Ignorando repositório: $repo_name (não contém '$REPO_FILTER')${NC}"
        fi
    done <<< "$(echo "$repos_response" | jq -c '.value[]')"
    
    echo -e "\n${GREEN}===========================================${NC}"
    if [[ "$DISABLE_MODE" == "true" ]]; then
        echo -e "${RED}Remoção de policies concluída!${NC}"
    else
        echo -e "${GREEN}Configuração de policies concluída!${NC}"
    fi
    echo -e "${GREEN}Total de repositórios encontrados: $found_count${NC}"
    echo -e "${GREEN}Total de repositórios processados: $processed_count${NC}"
    echo -e "${GREEN}===========================================${NC}"
}

main "$@"