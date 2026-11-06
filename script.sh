#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script com sudo: sudo bash $0"
  exit 1
fi
DOMINIO="cp.utfpr.edu.br"
SERVIDOR_IMPRESSORA="impressoras.cp.utfpr.edu.br"
IMPRESSORAS=("AMBULATORIO" "CIPECA" "CIPEMA" "COGERH" "DEMAP" "DEPRO" "DERAC" "DIREC" "DIRPPG" "FISICA" "G106" "GADIR" "GHI_01" "GHI_02" "INCUBADORA" "K" "LINGUAS" "PROFMAT" "QUADRA" "QUIMICA" "S323_01" "S323_02" "SECCOORD" "SEGEA")

echo "=== Instalador de Impressoras ==="

if command -v dpkg &> /dev/null; then
    TIPO_PACOTE="deb"
    DRIVER_NOME="dcpl5512.deb"
    URL_DRIVER="https://download.brother.com/welcome/dlf105822/dcpl5512dnpdrv-4.0.3-2.i386.deb"
elif command -v rpm &> /dev/null; then
    TIPO_PACOTE="rpm"
    DRIVER_NOME="dcpl5512.rpm"
    URL_DRIVER="https://download.brother.com/welcome/dlf105847/dcpl5512dnpdrv-4.0.3-3.i386.rpm"
else
    echo "Gerenciador de pacotes não suportado automaticamente."
    exit 1
fi

echo "Verificando e instalando dependências necessárias (CUPS, SMB)..."
if [ "$TIPO_PACOTE" = "deb" ]; then
    dpkg --add-architecture i386
    apt-get update
    apt-get install -y cups smbclient wget dpkg curl libc6:i386 libncurses5:i386 libstdc++6:i386
else
    yum install -y cups samba-client wget curl || dnf install -y cups samba-client wget curl
fi

systemctl enable --now cups

echo "Baixando o driver da impressora..."
wget "$URL_DRIVER" -O "/tmp/$DRIVER_NOME"

if [ "$TIPO_PACOTE" = "deb" ]; then
    dpkg -i "/tmp/$DRIVER_NOME"
else
    rpm -ivh --nodeps "/tmp/$DRIVER_NOME" 2>/dev/null || rpm -Uvh --force "/tmp/$DRIVER_NOME"
fi

echo ""
read -p "Digite seu usuário da rede UTFPR (ex: nome.sobrenome): " USUARIO
read -s -p "Digite sua senha da rede: " SENHA
echo ""

echo "Escolha a impressora:"
select LOCAL in "${IMPRESSORAS[@]}"; do
    if [ -n "$LOCAL" ]; then
        NOME_IMPRESSORA="${LOCAL}_DCPL5512DN"
        break
    else
        echo "Opção inválida. Tente novamente."
    fi
done

URI="smb://$DOMINIO%5C$USUARIO:$SENHA@$SERVIDOR_IMPRESSORA/$NOME_IMPRESSORA"

echo "Adicionando impressora..."
PPD_ARQUIVO=$(find /usr/share/ppd/ /usr/share/cups/model/ -name "*dcpl5512dn*.ppd" 2>/dev/null | head -n 1)

if [ -f "$PPD_ARQUIVO" ]; then
    lpadmin -p "$NOME_IMPRESSORA" -v "$URI" -E -L "$NOME_IMPRESSORA" -P "$PPD_ARQUIVO"
else
    lpadmin -p "$NOME_IMPRESSORA" -v "$URI" -E -L "$NOME_IMPRESSORA" -m everywhere
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "Impressora '$NOME_IMPRESSORA' instalada com sucesso!"
    echo "A impressora já deve aparecer configurada no painel de configurações do Ubuntu e pronta para uso."
else
    echo "Erro ao cadastrar a impressora no CUPS."
fi

unset SENHA