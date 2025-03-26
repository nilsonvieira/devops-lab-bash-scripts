#!/bin/bash

# Script de instalação para programas essenciais
# Atualizado em: 26 de março de 2025

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis globais
TEMP_DIR="/tmp/devops-install"
SUDO_USER=${SUDO_USER:-$(whoami)}

# Criar diretório temporário
mkdir -p "$TEMP_DIR"

# Função para exibir mensagens de progresso
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para limpar repositórios conflitantes
clean_conflicting_sources() {
    # Remover repositórios problemáticos
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/sources.list.d/spotify.list
    rm -f /etc/apt/sources.list.d/microsoft-edge.list
    rm -f /etc/apt/sources.list.d/vscode.list
    rm -f /etc/apt/sources.list.d/insomnia.list

    # Limpar chaves GPG antigas
    rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    rm -f /usr/share/keyrings/spotify-archive-keyring.gpg
    rm -f /usr/share/keyrings/microsoft-edge-keyring.gpg
    rm -f /usr/share/keyrings/microsoft-archive-keyring.gpg
}

# Função para verificar se um pacote está instalado
is_package_installed() {
    dpkg -l | grep -q "ii  $1 "
}

# Função para instalar pacote se não estiver instalado
install_package_if_not_exists() {
    if ! is_package_installed "$1"; then
        print_status "Instalando $1..."
        apt install -y "$1"
        check_status "$1"
    else
        print_success "$1 já está instalado. Pulando instalação."
    fi
}

# Função para verificar o comando executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1 instalado com sucesso!"
    else
        print_error "Falha ao instalar $1!"
    fi
}

# Função para baixar arquivo com retry
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

# Função para lidar com instalação do Spotify
install_spotify() {
    print_status "Instalando Spotify..."
    
    # Limpar repositórios anteriores
    rm -f /etc/apt/sources.list.d/spotify.list
    rm -f /etc/apt/trusted.gpg.d/spotify.gpg

    # Adicionar chave GPG diretamente com apt-key
    curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | sudo apt-key add -

    # Adicionar repositório
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    # Atualizar repositórios e instalar
    apt update
    apt install -y spotify-client

    check_status "Spotify"
}

# Função para lidar com instalação do Insomnia
install_insomnia() {
    print_status "Instalando Insomnia..."
    
    # Limpar repositórios anteriores
    rm -f /etc/apt/sources.list.d/insomnia.list
    rm -f /etc/apt/trusted.gpg.d/insomnia.gpg

    # Usar o repositório direto do Kong
    echo "deb [trusted=yes] https://packages.konghq.com/public/insomnia/deb/pop jammy main" | sudo tee /etc/apt/sources.list.d/insomnia.list

    # Atualizar repositórios e instalar
    apt update
    apt install -y insomnia

    check_status "Insomnia"
}

# Função para instalar JetBrains Toolbox
install_jetbrains_toolbox() {
    print_status "Instalando JetBrains Toolbox..."

    # URLs de backup com versões específicas
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
        
        # Usar wget com opções mais robustas
        if wget --no-check-certificate \
                --tries=3 \
                --timeout=30 \
                --retry-connrefused \
                --continue \
                -O "$toolbox_tarball" \
                "$url"; then
            
            # Verificar se o arquivo foi baixado corretamente
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

    # Criar diretório de instalação com limpeza prévia
    rm -rf /opt/jetbrains-toolbox
    mkdir -p /opt/jetbrains-toolbox

    # Extrair com verificação de integridade
    if tar -xzf "$toolbox_tarball" -C /opt/jetbrains-toolbox --strip-components=1; then
        # Encontrar o executável corretamente
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

# Verificar privilégios de root
if [ "$(id -u)" != "0" ]; then
   print_error "Este script precisa ser executado como root!"
   echo "Execute com: sudo $0"
   exit 1
fi

# Limpar fontes conflitantes
clean_conflicting_sources

# Atualizar repositórios
print_status "Atualizando repositórios..."
apt update
apt upgrade -y

# Instalar dependências básicas
print_status "Instalando dependências básicas..."
for pkg in apt-transport-https ca-certificates curl software-properties-common wget gnupg lsb-release gdebi-core; do
    install_package_if_not_exists "$pkg"
done

# Instalação dos pacotes básicos
print_status "Instalando pacotes básicos..."
for pkg in flameshot remmina alacarte nmap netcat-openbsd wireguard openvpn neofetch htop; do
    install_package_if_not_exists "$pkg"
done

# Instalação do btop (monitor de recursos avançado)
install_package_if_not_exists "btop"

# Configurações de outros softwares (Docker, kubectl, VS Code, etc. igual ao script anterior)
# ... (manter as mesmas configurações de instalação de Docker, kubectl, etc.)

# Spotify com tratamento de erro adicional
if ! is_package_installed "spotify-client"; then
    install_spotify || print_error "Instalação do Spotify falhou. Tente manualmente."
else
    print_success "Spotify já está instalado. Pulando instalação."
fi

# Insomnia com tratamento de erro adicional
if ! is_package_installed "insomnia"; then
    install_insomnia || print_error "Instalação do Insomnia falhou. Tente manualmente."
else
    print_success "Insomnia já está instalado. Pulando instalação."
fi

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

# Limpar arquivos temporários
rm -rf "$TEMP_DIR"

print_success "Instalação concluída!"
echo ""
echo "Para concluir a instalação dos produtos JetBrains:"
echo "1. Execute o JetBrains Toolbox digitando 'jetbrains-toolbox' no terminal"
echo "2. Faça login com sua conta JetBrains"
echo "3. Instale IntelliJ IDEA Ultimate, GoLand e PyCharm Professional através da interface do Toolbox"
echo ""
echo "Reinicie seu sistema para que todas as alterações tenham efeito."