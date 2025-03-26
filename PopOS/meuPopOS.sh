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

# Instalar dependências básicas
print_status "Instalando dependências básicas..."
apt install -y apt-transport-https ca-certificates curl software-properties-common wget gnupg lsb-release gdebi-core

# Instalação dos pacotes básicos
print_status "Instalando pacotes básicos..."
apt install -y flameshot remmina alacarte nmap netcat-openbsd wireguard openvpn
check_status "Pacotes básicos"

# Docker
print_status "Instalando Docker Engine..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker $SUDO_USER
check_status "Docker Engine"

# kubectl
print_status "Instalando kubectl..."
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubectl
check_status "kubectl"

# VS Code
print_status "Instalando Visual Studio Code..."
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list
apt update
apt install -y code
check_status "Visual Studio Code"

# Microsoft Edge
print_status "Instalando Microsoft Edge..."
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-edge-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list
apt update
apt install -y microsoft-edge-stable
check_status "Microsoft Edge"

# Postman (via pacote .deb)
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

# Insomnia
print_status "Instalando Insomnia..."
echo "deb [trusted=yes arch=amd64] https://download.konghq.com/insomnia-ubuntu/ default all" | tee /etc/apt/sources.list.d/insomnia.list
apt update
apt install -y insomnia
check_status "Insomnia"

# HashiCorp (Vagrant, Vault, Terraform)
print_status "Instalando produtos HashiCorp..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update
apt install -y vagrant vault terraform
check_status "Produtos HashiCorp"

# Discord
print_status "Instalando Discord..."
wget -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
dpkg -i /tmp/discord.deb
apt --fix-broken install -y
check_status "Discord"

# Spotify
print_status "Instalando Spotify..."
curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor | tee /usr/share/keyrings/spotify-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
apt update
apt install -y spotify-client
check_status "Spotify"

# Termius (via pacote .deb)
print_status "Instalando Termius..."
wget -O /tmp/termius.deb "https://www.termius.com/download/linux/Termius.deb"
dpkg -i /tmp/termius.deb
apt --fix-broken install -y
check_status "Termius"

# JetBrains Toolbox (para instalar IntelliJ Ultimate, GoLand, PyCharm Professional)
print_status "Instalando JetBrains Toolbox..."
JETBRAINS_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | grep -o "https://download.jetbrains.com/toolbox/jetbrains-toolbox-[0-9.]*.tar.gz")
wget -O /tmp/jetbrains-toolbox.tar.gz "$JETBRAINS_URL"
mkdir -p /opt/jetbrains-toolbox
tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
ln -s /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
chown -R $SUDO_USER:$SUDO_USER /opt/jetbrains-toolbox
check_status "JetBrains Toolbox"

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