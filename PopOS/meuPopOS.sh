#!/bin/bash

# Script de instalação para programas essenciais
# Atualizado em: 26 de março de 2025

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Docker - Instalação robusta com repositório oficial
if ! is_package_installed "docker-ce"; then
    print_status "Instalando Docker Engine..."
    # Remover possíveis instalações antigas
    apt-get remove -y docker docker-engine docker.io containerd runc

    # Preparar repositório Docker
    install_package_if_not_exists "ca-certificates"
    install_package_if_not_exists "curl"
    install_package_if_not_exists "gnupg"

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    usermod -aG docker $SUDO_USER
    check_status "Docker Engine"
else
    print_success "Docker Engine já está instalado. Pulando instalação."
fi

# Kubectl (usando repositório direto no Google Cloud)
if ! command -v kubectl &> /dev/null; then
    print_status "Instalando kubectl..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
    tee /etc/apt/sources.list.d/kubernetes.list
    
    chmod 644 /etc/apt/sources.list.d/kubernetes.list
    apt update
    apt install -y kubectl
    check_status "kubectl"
else
    print_success "kubectl já está instalado. Pulando instalação."
fi

# VS Code - Instalação a partir do repositório oficial da Microsoft
if ! is_package_installed "code"; then
    print_status "Instalando Visual Studio Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list
    apt update
    apt install -y code
    check_status "Visual Studio Code"
else
    print_success "Visual Studio Code já está instalado. Pulando instalação."
fi

# Microsoft Edge
if ! is_package_installed "microsoft-edge-stable"; then
    print_status "Instalando Microsoft Edge..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft-edge.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list
    apt update
    apt install -y microsoft-edge-stable
    check_status "Microsoft Edge"
else
    print_success "Microsoft Edge já está instalado. Pulando instalação."
fi

# HashiCorp (Vagrant, Vault, Terraform)
if ! is_package_installed "vagrant" || ! is_package_installed "vault" || ! is_package_installed "terraform"; then
    print_status "Instalando produtos HashiCorp..."
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/hashicorp.gpg
    chmod 644 /etc/apt/trusted.gpg.d/hashicorp.gpg
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update
    apt install -y vagrant vault terraform
    check_status "Produtos HashiCorp"
else
    print_success "Produtos HashiCorp já estão instalados. Pulando instalação."
fi

# Spotify (com tratamento adicional)
if ! is_package_installed "spotify-client"; then
    print_status "Instalando Spotify..."
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/spotify.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/spotify.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
    apt update
    apt install -y spotify-client || print_error "Falha ao instalar Spotify. Tente manualmente."
    check_status "Spotify"
else
    print_success "Spotify já está instalado. Pulando instalação."
fi

# Insomnia (com repositório alternativo)
if ! is_package_installed "insomnia"; then
    print_status "Instalando Insomnia..."
    curl -1sLf 'https://packages.konghq.com/public/insomnia/setup.deb.sh' | bash
    apt update
    apt install -y insomnia || print_error "Falha ao instalar Insomnia. Tente manualmente."
    check_status "Insomnia"
else
    print_success "Insomnia já está instalado. Pulando instalação."
fi

# JetBrains Toolbox
if [ ! -f "/usr/local/bin/jetbrains-toolbox" ]; then
    print_status "Instalando JetBrains Toolbox..."
    # Obter a URL de download mais recente corretamente
    JETBRAINS_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | grep -Po 'https://download.jetbrains.com/toolbox/jetbrains-toolbox-[0-9.]+.tar.gz')
    print_status "Baixando JetBrains Toolbox de: $JETBRAINS_URL"
    wget -O /tmp/jetbrains-toolbox.tar.gz "$JETBRAINS_URL"
    
    # Criar diretório de instalação
    mkdir -p /opt/jetbrains-toolbox
    tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
    
    # Criar link simbólico
    ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
    
    # Corrigir permissões
    chown -R $SUDO_USER:$SUDO_USER /opt/jetbrains-toolbox
    chmod +x /opt/jetbrains-toolbox/jetbrains-toolbox
    
    check_status "JetBrains Toolbox"
else
    print_success "JetBrains Toolbox já está instalado. Pulando instalação."
fi

# Limpeza final
print_status "Limpando pacotes desnecessários..."
apt autoremove -y
apt clean

print_success "Instalação concluída!"
echo ""
echo "Para concluir a instalação dos produtos JetBrains:"
echo "1. Execute o JetBrains Toolbox digitando 'jetbrains-toolbox' no terminal"
echo "2. Faça login com sua conta JetBrains"
echo "3. Instale IntelliJ IDEA Ultimate, GoLand e PyCharm Professional através da interface do Toolbox"
echo ""
echo "Reinicie seu sistema para que todas as alterações tenham efeito."