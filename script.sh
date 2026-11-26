#!/usr/bin/env bash

set -o pipefail

DOMINIO="cp.utfpr.edu.br"
SERVIDOR_IMPRESSORA="impressoras.cp.utfpr.edu.br"

IMPRESSORAS=(
    "AMBULATORIO" "CIPECA" "CIPEMA" "COGERH" "DEMAP" "DEPRO"
    "DERAC" "DIREC" "DIRPPG" "FISICA" "G106" "GADIR"
    "GHI_01" "INCUBADORA" "K" "LINGUAS" "PROFMAT"
    "QUADRA" "QUIMICA" "S323_01" "S323_02" "SECCOORD" "SEGEA" "SUBSOLO_A"
)

localizar_ppd() {
    find /usr/share/ppd /usr/share/cups/model \
        \( -type f -o -type l \) \
        -iname "*dcpl5512dn*.ppd" -print -quit 2>/dev/null
}

localizar_backend_smb() {
    local diretorio

    for diretorio in \
        /usr/lib/cups/backend \
        /usr/libexec/cups/backend \
        /usr/lib64/cups/backend
    do
        if [[ -x "$diretorio/smb" ]]; then
            echo "$diretorio/smb"
            return 0
        fi
    done

    return 1
}

echo "=== Instalador de Impressoras ==="

if [[ "$EUID" -ne 0 ]]; then
    echo "Por favor, execute este script com sudo: sudo bash $0"
    exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
    TIPO_PACOTE="deb"
    DRIVER_NOME="dcpl5512.deb"
    URL_DRIVER="https://download.brother.com/welcome/dlf105822/dcpl5512dnpdrv-4.0.3-2.i386.deb"
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    TIPO_PACOTE="rpm"
    DRIVER_NOME="dcpl5512.rpm"
    URL_DRIVER="https://download.brother.com/welcome/dlf105847/dcpl5512dnpdrv-4.0.3-3.i386.rpm"
else
    TIPO_PACOTE="manual"
    echo "Distribuição não suportada para instalação automática."
    if ! command -v lpadmin >/dev/null 2>&1; then
        echo "ERRO: CUPS não está instalado."
        exit 1
    fi

    if ! systemctl enable --now cups; then
        echo "ERRO: não foi possível ativar o serviço CUPS."
        exit 1
    fi

    if ! command -v smbclient >/dev/null 2>&1; then
        echo "ERRO: smbclient não está instalado."
        exit 1
    fi

    BACKEND_SMB=$(localizar_backend_smb)

    if [[ -z "$BACKEND_SMB" ]]; then
        echo "ERRO: backend SMB do CUPS não encontrado."
        exit 1
    fi

    PPD_ARQUIVO=$(localizar_ppd)

    if [[ -z "$PPD_ARQUIVO" || ! -f "$PPD_ARQUIVO" ]]; then
        echo "ERRO: driver Brother DCP-L5512DN não encontrado."
        exit 1
    fi
fi

if [[ "$TIPO_PACOTE" != "manual" ]]; then
    trap 'rm -f "/tmp/$DRIVER_NOME"' EXIT
fi

PPD_ARQUIVO=$(localizar_ppd)

if [[ "$TIPO_PACOTE" != "manual" ]]; then

    if [[ "$TIPO_PACOTE" == "deb" ]]; then
        PACOTES=("cups" "smbclient" "wget")
        PACOTES_FALTANDO=()
        ATUALIZAR_LISTAS=false

        if ! dpkg --print-foreign-architectures | grep -qx i386; then
            dpkg --add-architecture i386
            ATUALIZAR_LISTAS=true
        fi

        for PACOTE in "${PACOTES[@]}"; do
            if ! dpkg-query -W -f='${db:Status-Status}' "$PACOTE" 2>/dev/null | grep -qx installed; then
                PACOTES_FALTANDO+=("$PACOTE")
            fi
        done

        if [[ ${#PACOTES_FALTANDO[@]} -gt 0 ]]; then
            ATUALIZAR_LISTAS=true
        fi

        if [[ -z "$PPD_ARQUIVO" || ! -f "$PPD_ARQUIVO" ]]; then
            ATUALIZAR_LISTAS=true
        fi

        if [[ "$ATUALIZAR_LISTAS" == true ]]; then
            apt-get update
        fi

        if [[ ${#PACOTES_FALTANDO[@]} -gt 0 ]]; then
            if ! apt-get install -y "${PACOTES_FALTANDO[@]}"; then
                echo "ERRO: não foi possível instalar os pacotes essenciais."
                exit 1
            fi
        fi

    else
        if command -v dnf >/dev/null 2>&1; then
            GERENCIADOR_RPM="dnf"
        else
            GERENCIADOR_RPM="yum"
        fi

        PACOTES=("cups" "samba-client" "wget")
        PACOTES_FALTANDO=()

        for PACOTE in "${PACOTES[@]}"; do
            if ! rpm -q "$PACOTE" >/dev/null 2>&1; then
                PACOTES_FALTANDO+=("$PACOTE")
            fi
        done

        if [[ ${#PACOTES_FALTANDO[@]} -gt 0 ]]; then
            if ! "$GERENCIADOR_RPM" install -y "${PACOTES_FALTANDO[@]}"; then
                echo "ERRO: não foi possível instalar os pacotes essenciais."
                exit 1
            fi
        fi
    fi

    if ! systemctl enable --now cups; then
        echo "ERRO: não foi possível iniciar/ativar o serviço CUPS."
        exit 1
    fi

    if [[ -z "$PPD_ARQUIVO" || ! -f "$PPD_ARQUIVO" ]]; then
        echo "Instalando driver Brother..."

        if ! wget -O "/tmp/$DRIVER_NOME" "$URL_DRIVER"; then
            echo "ERRO: não foi possível baixar o driver."
            exit 1
        fi

        if [[ ! -s "/tmp/$DRIVER_NOME" ]]; then
            echo "ERRO: o arquivo do driver foi baixado vazio."
            exit 1
        fi

        if [[ "$TIPO_PACOTE" == "deb" ]]; then
            if ! apt-get install -y --no-install-recommends "/tmp/$DRIVER_NOME"; then
                echo "ERRO: não foi possível instalar o driver Brother ou resolver suas dependências."
                exit 1
            fi
        else
            if ! "$GERENCIADOR_RPM" install -y "/tmp/$DRIVER_NOME"; then
                echo "ERRO: não foi possível instalar o driver Brother ou resolver suas dependências."
                exit 1
            fi
        fi

        PPD_ARQUIVO=$(localizar_ppd)

        if [[ -z "$PPD_ARQUIVO" || ! -f "$PPD_ARQUIVO" ]]; then
            echo "ERRO: driver instalado, mas arquivo PPD não encontrado."
            exit 1
        fi
    else
        echo "Driver Brother já instalado. Pulando instalação."
    fi
fi

echo
read -r -p "Digite seu usuário da rede UTFPR (ex: nome.sobrenome): " USUARIO

if [[ -z "$USUARIO" ]]; then
    echo "ERRO: o usuário não pode ficar vazio."
    exit 1
fi

read -r -s -p "Digite sua senha da rede: " SENHA
echo

if [[ -z "$SENHA" ]]; then
    echo "ERRO: a senha não pode ficar vazia."
    exit 1
fi

urlencode() {
    local LC_ALL=C
    local entrada="$1"
    local resultado=""
    local caractere
    local codigo
    local i

    for ((i = 0; i < ${#entrada}; i++)); do
        caractere="${entrada:i:1}"

        case "$caractere" in
            [a-zA-Z0-9.~_-])
                resultado+="$caractere"
                ;;
            *)
                printf -v codigo '%%%02X' "'$caractere"
                resultado+="$codigo"
                ;;
        esac
    done

    printf '%s' "$resultado"
}

USUARIO_ENCODED=$(urlencode "$USUARIO")
SENHA_ENCODED=$(urlencode "$SENHA")

echo "Escolha a impressora:"
select LOCAL in "${IMPRESSORAS[@]}"; do
    if [[ -n "$LOCAL" ]]; then
        NOME_IMPRESSORA="${LOCAL}_DCPL5512DN"
        break
    else
        echo "Opção inválida. Tente novamente."
    fi
done

URI="smb://${DOMINIO}%5C${USUARIO_ENCODED}:${SENHA_ENCODED}@${SERVIDOR_IMPRESSORA}/${NOME_IMPRESSORA}"

unset SENHA SENHA_ENCODED USUARIO_ENCODED

if lpadmin -p "$NOME_IMPRESSORA" \
    -v "$URI" \
    -E \
    -L "$NOME_IMPRESSORA" \
    -P "$PPD_ARQUIVO"; then

    echo
    echo "Impressora '$NOME_IMPRESSORA' instalada com sucesso!"
else
    echo
    echo "ERRO: não foi possível cadastrar a impressora no CUPS."
    unset URI
    exit 1
fi

unset URI
exit 0

