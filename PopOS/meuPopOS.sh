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

# Função para verificar se o comando foi executado com sucesso
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

# Atualizar repositórios
print_status "Atualizando repositórios..."
apt update
apt upgrade -y

# Função para instalar a partir de .deb com verificação
install_deb_if_not_exists() {
    local package_name="$1"
    local deb_path="$2"
    
    if ! is_package_installed "$package_name"; then
        print_status "Instalando $package_name..."
        wget -O "/tmp/$(basename "$deb_path")" "$deb_path"
        dpkg -i "/tmp/$(basename "$deb_path")"
        apt --fix-broken install -y
        check_status "$package_name"
    else
        print_success "$package_name já está instalado. Pulando instalação."
    fi
}

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

# Docker - Adicionar verificação de instalação
if ! is_package_installed "docker-ce"; then
    print_status "Instalando Docker Engine..."
    # Remover possíveis instalações antigas de chaves Docker
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # Adicionar chave GPG oficial do Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Adicionar repositório stable
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker
    usermod -aG docker $SUDO_USER
    check_status "Docker Engine"
else
    print_success "Docker Engine já está instalado. Pulando instalação."
fi

# kubectl - Adicionar verificação de instalação
if ! command -v kubectl &> /dev/null; then
    print_status "Instalando kubectl..."
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    apt update
    apt install -y kubectl
    check_status "kubectl"
else
    print_success "kubectl já está instalado. Pulando instalação."
fi

# Lens (K8s Lens) - Usar função de instalação de .deb
install_deb_if_not_exists "lens" "https://api.k8slens.dev/binaries/Lens-latest.deb"

# VS Code - Adicionar verificação de instalação
if ! is_package_installed "code"; then
    print_status "Instalando Visual Studio Code..."
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list
    apt update
    apt install -y code
    check_status "Visual Studio Code"
else
    print_success "Visual Studio Code já está instalado. Pulando instalação."
fi

# Microsoft Edge - Adicionar verificação de instalação
if ! is_package_installed "microsoft-edge-stable"; then
    print_status "Instalando Microsoft Edge..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-edge-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list
    apt update
    apt install -y microsoft-edge-stable
    check_status "Microsoft Edge"
else
    print_success "Microsoft Edge já está instalado. Pulando instalação."
fi

# Postman - Usar função de instalação personalizada
if [ ! -d "/opt/postman" ]; then
    print_status "Instalando Postman..."
    wget -O /tmp/postman.tar.gz "https://dl.pstmn.io/download/latest/linux64"
    mkdir -p /opt/postman
    tar -xzf /tmp/postman.tar.gz -C /opt/postman --strip-components=1
    ln -s /opt/postman/Postman /usr/local/bin/postman
    cat > /usr/share/applications/postman.desktop <<EOL
[Desktop Entry]
Name=Postman
GenericName=API Client
X-GNOME-FullName=Postman API Client
Comment=Make and view REST API calls and responses
Keywords=api;
Exec=/opt/postman/Postman
Terminal=false
Type=Application
Icon=/opt/postman/app/resources/app/assets/icon.png
Categories=Development;Utilities;
EOL
    check_status "Postman"
else
    print_success "Postman já está instalado. Pulando instalação."
fi

# Insomnia
if ! is_package_installed "insomnia"; then
    print_status "Instalando Insomnia..."
    echo "deb [trusted=yes arch=amd64] https://download.konghq.com/insomnia-ubuntu/ default all" | tee /etc/apt/sources.list.d/insomnia.list
    apt update
    apt install -y insomnia
    check_status "Insomnia"
else
    print_success "Insomnia já está instalado. Pulando instalação."
fi

# HashiCorp (Vagrant, Vault, Terraform)
if ! is_package_installed "vagrant" || ! is_package_installed "vault" || ! is_package_installed "terraform"; then
    print_status "Instalando produtos HashiCorp..."
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update
    apt install -y vagrant vault terraform
    check_status "Produtos HashiCorp"
else
    print_success "Produtos HashiCorp já estão instalados. Pulando instalação."
fi

# Discord
install_deb_if_not_exists "discord" "https://discord.com/api/download?platform=linux&format=deb"

# Spotify
if ! is_package_installed "spotify-client"; then
    print_status "Instalando Spotify..."
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor | tee /usr/share/keyrings/spotify-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
    apt update
    apt install -y spotify-client
    check_status "Spotify"
else
    print_success "Spotify já está instalado. Pulando instalação."
fi

# Termius
install_deb_if_not_exists "termius" "https://www.termius.com/download/linux/Termius.deb"

# JetBrains Toolbox
if [ ! -d "/opt/jetbrains-toolbox" ]; then
    print_status "Instalando JetBrains Toolbox..."
    # Obter a URL de download mais recente corretamente
    JETBRAINS_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | grep -Po 'https://download.jetbrains.com/toolbox/jetbrains-toolbox-[0-9.]+.tar.gz')
    print_status "Baixando JetBrains Toolbox de: $JETBRAINS_URL"
    wget -O /tmp/jetbrains-toolbox.tar.gz "$JETBRAINS_URL"
    mkdir -p /opt/jetbrains-toolbox
    tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
    ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
    chown -R $SUDO_USER:$SUDO_USER /opt/jetbrains-toolbox
    check_status "JetBrains Toolbox"
else
    print_success "JetBrains Toolbox já está instalado. Pulando instalação."
fi

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