#!/usr/bin/env bash
set -euo pipefail

# create_user_with_ssh.sh
# Uso:
#   sudo ./create_user_with_ssh.sh <usuario> [--sudo] [--out /caminho/para/salvar_chave_privada]
# Exemplo:
#   sudo ./create_user_with_ssh.sh victor.silva --sudo --out /root/victor_id_ed25519

# --------- Configurações ---------
TIPO_CHAVE="ed25519"             # Tipo de chave (segura e moderna)
NOME_ARQUIVO_CHAVE="id_${TIPO_CHAVE}"
SHELL_PADRAO="/bin/bash"
# ---------------------------------

mostrar_ajuda() {
  cat <<EOF
Uso: sudo $0 <usuario> [--sudo] [--out /caminho/para/salvar_chave_privada] [--force]
Cria um usuário, gera um par de chaves SSH, configura authorized_keys e retorna a chave privada.
Opções:
  --sudo       Adiciona o usuário ao grupo 'sudo'
  --out ARQ    Salva a chave privada no arquivo ARQ (com permissão 600). Se não for informado, a chave será exibida na tela.
  --force      Caso o usuário já exista, sobrescreve as chaves SSH existentes (use com cuidado).
EOF
  exit 1
}

# Verifica se está rodando como root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "❌ Este script precisa ser executado como root (use sudo)." >&2
  exit 2
fi

if [[ $# -lt 1 ]]; then
  mostrar_ajuda
fi

USUARIO=""
ARQUIVO_SAIDA=""
ADICIONAR_SUDO=false
FORCAR=false

# Leitura dos parâmetros
ARG_POSICIONAIS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sudo) ADICIONAR_SUDO=true; shift ;;
    --out) ARQUIVO_SAIDA="$2"; shift 2 ;;
    --force) FORCAR=true; shift ;;
    -h|--help) mostrar_ajuda ;;
    --) shift; break ;;
    -*)
      echo "Opção desconhecida: $1" >&2
      mostrar_ajuda
      ;;
    *)
      ARG_POSICIONAIS+=("$1"); shift
      ;;
  esac
done

if [[ ${#ARG_POSICIONAIS[@]} -lt 1 ]]; then
  mostrar_ajuda
fi

USUARIO="${ARG_POSICIONAIS[0]}"

# Valida o nome do usuário
if ! [[ "$USUARIO" =~ ^[a-z_][a-z0-9_.-]{0,31}$ ]]; then
  echo "❌ Nome de usuário inválido: '$USUARIO'. Use apenas letras minúsculas, números, pontos, traços e underscores (máx. 32 caracteres)." >&2
  exit 3
fi

DIR_HOME="/home/${USUARIO}"
DIR_SSH="${DIR_HOME}/.ssh"
CAMINHO_CHAVE="${DIR_SSH}/${NOME_ARQUIVO_CHAVE}"
CHAVE_PRIVADA="${CAMINHO_CHAVE}"
CHAVE_PUBLICA="${CAMINHO_CHAVE}.pub"
AUTHORIZED_KEYS="${DIR_SSH}/authorized_keys"

# Verifica se o usuário já existe
if id "$USUARIO" &>/dev/null; then
  if [ "$FORCAR" = true ]; then
    echo "⚠️  Usuário $USUARIO já existe e a opção --force foi informada. As chaves existentes serão substituídas."
  else
    echo "❌ Usuário $USUARIO já existe. Use --force para sobrescrever as chaves ou escolha outro nome." >&2
    exit 4
  fi
else
  # Cria o usuário com diretório home e shell padrão
  useradd -m -s "${SHELL_PADRAO}" "$USUARIO"
  echo "✅ Usuário criado: $USUARIO (home: ${DIR_HOME})"
fi

# Garante que o diretório home exista
if [ ! -d "$DIR_HOME" ]; then
  mkdir -p "$DIR_HOME"
  chown "$USUARIO":"$USUARIO" "$DIR_HOME"
  chmod 755 "$DIR_HOME"
fi

# Cria o diretório .ssh
mkdir -p "$DIR_SSH"
chown "$USUARIO":"$USUARIO" "$DIR_SSH"
chmod 700 "$DIR_SSH"

# Faz backup de chaves antigas, se existirem
if [ -f "$CHAVE_PRIVADA" ] || [ -f "$CHAVE_PUBLICA" ]; then
  if [ "$FORCAR" = true ]; then
    ts=$(date +%s)
    echo "🔁 Fazendo backup das chaves antigas em ${CHAVE_PRIVADA}.bak.${ts}"
    [ -f "$CHAVE_PRIVADA" ] && mv -f "$CHAVE_PRIVADA" "${CHAVE_PRIVADA}.bak.${ts}"
    [ -f "$CHAVE_PUBLICA" ] && mv -f "$CHAVE_PUBLICA" "${CHAVE_PUBLICA}.bak.${ts}"
  else
    echo "❌ Já existem chaves SSH em ${CHAVE_PRIVADA}. Use --force para sobrescrever." >&2
    exit 5
  fi
fi

# Gera o par de chaves SSH
sudo -u "$USUARIO" bash -c "cd \"$DIR_SSH\" && ssh-keygen -t \"$TIPO_CHAVE\" -f \"$NOME_ARQUIVO_CHAVE\" -N \"\" -C \"${USUARIO}@$(hostname)-$(date +%F)\" -q"

# Ajusta permissões
chown "$USUARIO":"$USUARIO" "${CHAVE_PRIVADA}" "${CHAVE_PUBLICA}"
chmod 600 "${CHAVE_PRIVADA}"
chmod 644 "${CHAVE_PUBLICA}"

# Adiciona a chave pública ao authorized_keys
touch "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"
chown "$USUARIO":"$USUARIO" "${AUTHORIZED_KEYS}"

if ! grep -qs -F "$(cat "${CHAVE_PUBLICA}")" "${AUTHORIZED_KEYS}"; then
  cat "${CHAVE_PUBLICA}" >> "${AUTHORIZED_KEYS}"
  echo "🔑 Chave pública adicionada a ${AUTHORIZED_KEYS}"
else
  echo "ℹ️  Chave pública já estava presente em ${AUTHORIZED_KEYS}"
fi

# Adiciona ao grupo sudo, se solicitado
if [ "$ADICIONAR_SUDO" = true ]; then
  usermod -aG sudo "$USUARIO"
  echo "👑 Usuário $USUARIO adicionado ao grupo sudo"
fi

# Exibe ou salva a chave privada
CONTEUDO_CHAVE="$(cat "${CHAVE_PRIVADA}")"

if [[ -n "$ARQUIVO_SAIDA" ]]; then
  umask 077
  echo "$CONTEUDO_CHAVE" > "$ARQUIVO_SAIDA"
  chmod 600 "$ARQUIVO_SAIDA"
  echo "💾 Chave privada salva em: $ARQUIVO_SAIDA (permissão 600)"
  echo "⚠️  Guarde essa chave em local seguro e remova qualquer cópia desnecessária."
else
  cat <<'EOF'

===== INÍCIO DA CHAVE PRIVADA (copie tudo entre as linhas) =====
EOF
  printf '%s\n' "$CONTEUDO_CHAVE"
  cat <<'EOF'
===== FIM DA CHAVE PRIVADA =====

⚠️ IMPORTANTE:
- Salve essa chave imediatamente em um arquivo seguro (chmod 600).
- NÃO deixe essa chave em logs, histórico ou prints.
- Se você fechar o terminal sem salvar, não poderá recuperá-la.
EOF
fi

# Resumo final
cat <<EOF

📋 Resumo da operação:
  👤 Usuário:           ${USUARIO}
  🏠 Diretório home:    ${DIR_HOME}
  📂 Pasta SSH:         ${DIR_SSH}
  🔐 Chave privada:     ${CHAVE_PRIVADA}
  🔓 Chave pública:     ${CHAVE_PUBLICA}
  🪪 Authorized_keys:   ${AUTHORIZED_KEYS}

Notas:
- A chave privada também foi mantida em ~/.ssh/ do usuário no servidor.
- Se usou --out, a chave privada está salva nesse caminho com permissão 600.
- Caso tenha copiado da tela, salve-a com segurança e apague qualquer cópia temporária.

✅ Finalizado com sucesso.
EOF

exit 0
