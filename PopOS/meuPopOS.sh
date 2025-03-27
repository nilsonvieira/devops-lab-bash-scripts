#!/bin/bash

# Script de Instalação de Ambiente DevOps
# Autor: Nilson Vieira
# Data: 26 de março de 2025
# Descrição: Script automatizado para configuração de ambiente de desenvolvimento

# ===============================
# Configuração de Cores
# ===============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem Cor

# ===============================
# Variáveis Globais
# ===============================
TEMP_DIR="/tmp/devops-install"
SUDO_USER=${SUDO_USER:-$(whoami)}

# Criar diretório temporário
mkdir -p "$TEMP_DIR"

# ===============================
# Funções de Log e Status
# ===============================
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# ===============================
# Funções de Limpeza de Repositórios
# ===============================
clean_conflicting_sources() {
    print_status "Removendo configurações de repositórios conflitantes..."
    
    local repos_to_remove=(
        "/etc/apt/sources.list.d/kubernetes.list"
        "/etc/apt/sources.list.d/docker.list"
        "/etc/apt/sources.list.d/spotify.list"
        "/etc/apt/sources.list.d/microsoft-edge.list"
        "/etc/apt/sources.list.d/vscode.list"
        "/etc/apt/sources.list.d/insomnia.list"
    )

    local keys_to_remove=(
        "/usr/share/keyrings/kubernetes-archive-keyring.gpg"
        "/usr/share/keyrings/docker-archive-keyring.gpg"
        "/usr/share/keyrings/spotify-archive-keyring.gpg"
        "/usr/share/keyrings/microsoft-edge-keyring.gpg"
        "/usr/share/keyrings/microsoft-archive-keyring.gpg"
    )

    # Remover arquivos de repositórios
    for repo in "${repos_to_remove[@]}"; do
        [ -f "$repo" ] && rm -f "$repo"
    done

    # Remover chaves GPG
    for key in "${keys_to_remove[@]}"; do
        [ -f "$key" ] && rm -f "$key"
    done
}

clean_problematic_repos() {
    print_status "Removendo configurações de Spotify e Insomnia..."
    
    local repos_to_remove=(
        "/etc/apt/sources.list.d/spotify.list"
        "/etc/apt/sources.list.d/insomnia.list"
        "/etc/apt/trusted.gpg.d/spotify.gpg"
        "/etc/apt/trusted.gpg.d/insomnia.gpg"
    )

    local keys_to_remove=(
        "931FF8E79F0876134CC00E099B548F9F7E7A9BB9"  # Spotify
        "7A3A762FAFD4A51F"  # Spotify alternativa
        "1A127079A92FAF90"  # Insomnia
    )

    # Remover arquivos de repositórios
    for repo in "${repos_to_remove[@]}"; do
        [ -f "$repo" ] && rm -f "$repo"
    done

    # Remover chaves GPG de forma segura
    for key in "${keys_to_remove[@]}"; do
        gpg --batch --yes --delete-keys "$key" 2>/dev/null || true
    done

    # Limpar cache do apt
    apt clean
    apt update
}

# ===============================
# Funções de Verificação de Pacotes
# ===============================
is_package_installed() {
    dpkg -l | grep -q "ii  $1 "
}

install_package_if_not_exists() {
    if ! is_package_installed "$1"; then
        print_status "Instalando $1..."
        apt install -y "$1"
        check_status "$1"
    else
        print_success "$1 já está instalado. Pulando instalação."
    fi
}

check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1 instalado com sucesso!"
    else
        print_error "Falha ao instalar $1!"
    fi
}

# ===============================
# Funções de Download
# ===============================
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        print_status "Download: $url (Tentativa $((retry_count+1)))"
        if wget -q -O "$output" "$url"; then
            return 0
        fi
        ((retry_count++))
        sleep 2
    done

    print_error "Falha no download após $max_retries tentativas"
    return 1
}

# ===============================
# Funções de Configuração de Repositórios
# ===============================
fix_docker_repository() {
    print_status "Corrigindo repositório Docker..."

    # Remover configurações antigas e conflitantes
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # Remover entradas existentes no sources.list
    sed -i '/download\.docker\.com/d' /etc/apt/sources.list
    sed -i '/download\.docker\.com/d' /etc/apt/sources.list.d/*

    # Criar diretório para chaves se não existir
    mkdir -p /etc/apt/keyrings

    # Baixar e adicionar chave GPG
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Obter o nome do sistema operacional e versão
    local os_codename
    os_codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

    # Adicionar repositório com configuração limpa
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $os_codename stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Atualizar repositórios
    apt update
}

# ===============================
# Funções de Instalação de Softwares
# ===============================
install_jetbrains_toolbox() {
    print_status "Instalando JetBrains Toolbox..."

    local toolbox_urls=(
        "https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.5.4.38621.tar.gz"
        "https://download-cdn.jetbrains.com/toolbox/jetbrains-toolbox-2.5.4.38621.tar.gz"
        "https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.3.14.182.tar.gz"
        "https://download-cdn.jetbrains.com/toolbox/jetbrains-toolbox-2.3.14.182.tar.gz"
    )

    local download_success=false
    local toolbox_tarball="$TEMP_DIR/jetbrains-toolbox.tar.gz"

    # Tentar baixar de diferentes URLs
    for url in "${toolbox_urls[@]}"; do
        print_status "Tentando baixar de: $url"
        
        if wget --no-check-certificate \
                --tries=3 \
                --timeout=30 \
                --retry-connrefused \
                --continue \
                -O "$toolbox_tarball" \
                "$url"; then
            
            if [ -s "$toolbox_tarball" ]; then
                download_success=true
                break
            else
                print_error "Arquivo baixado está vazio: $url"
            fi
        else
            print_error "Falha ao baixar: $url"
        fi
    done

    if [ "$download_success" = false ]; then
        print_error "Não foi possível baixar o JetBrains Toolbox"
        return 1
    fi

    # Limpar e criar diretório
    rm -rf /opt/jetbrains-toolbox
    mkdir -p /opt/jetbrains-toolbox

    # Extrair
    if tar -xzf "$toolbox_tarball" -C /opt/jetbrains-toolbox --strip-components=1; then
        # Encontrar executável
        local toolbox_executable
        toolbox_executable=$(find /opt/jetbrains-toolbox -type f -name "jetbrains-toolbox" | head -n 1)

        if [ -z "$toolbox_executable" ]; then
            print_error "Executável do JetBrains Toolbox não encontrado"
            return 1
        fi

        # Criar link simbólico
        ln -sf "$toolbox_executable" /usr/local/bin/jetbrains-toolbox

        # Corrigir permissões
        chown -R "$SUDO_USER:$SUDO_USER" /opt/jetbrains-toolbox
        chmod +x "$toolbox_executable"

        check_status "JetBrains Toolbox"
    else
        print_error "Falha ao extrair JetBrains Toolbox"
        return 1
    fi
}

# ===============================
# Script Principal
# ===============================
main() {
    # Verificar privilégios de root
    if [ "$(id -u)" != "0" ]; then
       print_error "Este script precisa ser executado como root!"
       echo "Execute com: sudo $0"
       exit 1
    fi

    # Limpeza inicial
    clean_conflicting_sources
    fix_docker_repository
    clean_problematic_repos

    # Atualizar repositórios
    print_status "Atualizando repositórios..."
    apt update
    apt upgrade -y

    # Instalar dependências básicas
    print_status "Instalando dependências básicas..."
    local basic_deps=(
        apt-transport-https 
        ca-certificates 
        curl 
        software-properties-common 
        wget 
        gnupg 
        lsb-release 
        gdebi-core
    )
    for pkg in "${basic_deps[@]}"; do
        install_package_if_not_exists "$pkg"
    done

    # Instalar pacotes básicos
    print_status "Instalando pacotes básicos..."
    local basic_packages=(
        flameshot 
        remmina 
        alacarte 
        nmap 
        netcat-openbsd 
        wireguard 
        openvpn 
        neofetch 
        htop 
        btop
    )
    for pkg in "${basic_packages[@]}"; do
        install_package_if_not_exists "$pkg"
    done

    # JetBrains Toolbox
    if [ ! -f "/usr/local/bin/jetbrains-toolbox" ]; then
        install_jetbrains_toolbox || print_error "Instalação do JetBrains Toolbox falhou. Tente manualmente."
    else
        print_success "JetBrains Toolbox já está instalado. Pulando instalação."
    fi

    # Limpeza final
    print_status "Limpando pacotes desnecessários..."
    apt autoremove -y
    apt clean
    rm -rf "$TEMP_DIR"

    # Mensagem de conclusão
    print_success "Instalação concluída!"
    echo ""
    echo "Para concluir a instalação dos produtos JetBrains:"
    echo "1. Execute o JetBrains Toolbox digitando 'jetbrains-toolbox' no terminal"
    echo "2. Faça login com sua conta JetBrains"
    echo "3. Instale IntelliJ IDEA Ultimate, GoLand e PyCharm Professional através da interface do Toolbox"
    echo ""
    echo "Reinicie seu sistema para que todas as alterações tenham efeito."
}

# Executar script principal
main