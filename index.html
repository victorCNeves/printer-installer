#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script com sudo: sudo bash $0"
  exit 1
fi
DRIVER_DEB="dcpl5512.deb"
URL_DRIVER="https://download.brother.com/welcome/dlf105822/dcpl5512dnpdrv-4.0.3-2.i386.deb"
DOMINIO="cp.utfpr.edu.br"
SERVIDOR_IMPRESSORA="impressoras.cp.utfpr.edu.br"
IMPRESSORAS=("AMBULATORIO" "CIPECA" "CIPEMA" "COGERH" "DEMAP" "DEPRO" "DERAC" "DIREC" "DIRPPG" "FISICA" "G106" "GADIR" "GHI_01" "GHI_02" "INCUBADORA" "K" "LINGUAS" "PROFMAT" "QUADRA" "QUIMICA" "S323_01" "S323_02" "SECCOORD" "SEGEA")

echo "=== Instalador de Impressoras ==="

echo "Verificando e instalando dependências necessárias (CUPS, SMB)..."
dpkg --add-architecture i386
apt-get update
apt-get install -y cups smbclient wget dpkg curl libc6:i386 libncurses5:i386 libstdc++6:i386

systemctl enable --now cups

echo "Baixando o driver da impressora..."
wget "$URL_DRIVER" -O "/tmp/$DRIVER_DEB"
dpkg -i "/tmp/$DRIVER_DEB"

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
PPD_ARQUIVO=$(find /usr/share/ppd/ -name "*DCPL5512DN*.ppd" | head -n 1)

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