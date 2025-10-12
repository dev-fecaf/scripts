#!/usr/bin/env bash
set -euo pipefail

# create_user_with_ssh.sh
# Usage:
#   sudo ./create_user_with_ssh.sh <username> [--sudo] [--out /path/to/save_private_key]
# Examples:
#   sudo ./create_user_with_ssh.sh victor.silva
#   sudo ./create_user_with_ssh.sh victor.silva --sudo --out /root/victor_id

# --------- Configuration ---------
KEY_TYPE="ed25519"            # strong, short keys
KEY_FILENAME="id_${KEY_TYPE}" # name inside ~/.ssh/
DEFAULT_SHELL="/bin/bash"
# ---------------------------------

usage() {
  cat <<EOF
Usage: sudo $0 <username> [--sudo] [--out /path/to/save_private_key] [--force]
Creates a user, generates SSH keypair, configures authorized_keys and returns the private key.
Options:
  --sudo      Add the user to 'sudo' group
  --out FILE  Save private key to FILE (will be chmod 600). If not provided, private key is printed to stdout.
  --force     If user exists, overwrite SSH keys and authorized_keys (use with care).
EOF
  exit 1
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 2
fi

if [[ $# -lt 1 ]]; then
  usage
fi

USERNAME=""
OUTFILE=""
ADD_SUDO=false
FORCE=false

# simple args parsing
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sudo) ADD_SUDO=true; shift ;;
    --out) OUTFILE="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      POSITIONAL+=("$1"); shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 1 ]]; then
  usage
fi

USERNAME="${POSITIONAL[0]}"

# Validate username (allow letters, digits, dot, underscore, dash)
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_.-]{0,31}$ ]]; then
  echo "Invalid username: '$USERNAME'. Use lowercase, start with letter/underscore, only [a-z0-9_.-], max length 32." >&2
  exit 3
fi

HOME_DIR="/home/${USERNAME}"
SSH_DIR="${HOME_DIR}/.ssh"
KEY_PATH="${SSH_DIR}/${KEY_FILENAME}"
PRIV_KEY_PATH="${KEY_PATH}"
PUB_KEY_PATH="${KEY_PATH}.pub"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

# If user exists
if id "$USERNAME" &>/dev/null; then
  if [ "$FORCE" = true ]; then
    echo "User $USERNAME already exists and --force provided: will keep user and overwrite keys."
  else
    echo "User $USERNAME already exists. Use --force to overwrite keys or choose another name." >&2
    exit 4
  fi
else
  # create user with home dir and shell
  useradd -m -s "${DEFAULT_SHELL}" "$USERNAME"
  echo "Created user: $USERNAME (home: ${HOME_DIR})"
fi

# ensure home exists (in rare cases useradd exists but no home)
if [ ! -d "$HOME_DIR" ]; then
  mkdir -p "$HOME_DIR"
  chown "$USERNAME":"$USERNAME" "$HOME_DIR"
  chmod 755 "$HOME_DIR"
fi

# create .ssh dir
mkdir -p "$SSH_DIR"
chown "$USERNAME":"$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Backup existing keys if present and not forced
if [ -f "$PRIV_KEY_PATH" ] || [ -f "$PUB_KEY_PATH" ]; then
  if [ "$FORCE" = true ]; then
    ts=$(date +%s)
    echo "Backing up existing keys to ${PRIV_KEY_PATH}.bak.${ts}"
    [ -f "$PRIV_KEY_PATH" ] && mv -f "$PRIV_KEY_PATH" "${PRIV_KEY_PATH}.bak.${ts}"
    [ -f "$PUB_KEY_PATH" ]  && mv -f "$PUB_KEY_PATH"  "${PUB_KEY_PATH}.bak.${ts}"
  else
    echo "SSH key already exists at ${PRIV_KEY_PATH}. Use --force to overwrite." >&2
    exit 5
  fi
fi

# Generate keypair as the target user (safer ownership)
# Use -q for quiet (but we still report)
sudo -u "$USERNAME" ssh-keygen -t "$KEY_TYPE" -f "$KEY_FILENAME" -N "" -C "${USERNAME}@$(hostname)-$(date +%F)" -q 2>/dev/null || {
  # ssh-keygen writes to current directory for relative filename, so run it in SSH_DIR
  sudo -u "$USERNAME" bash -c "cd \"$SSH_DIR\" && ssh-keygen -t \"$KEY_TYPE\" -f \"$KEY_FILENAME\" -N \"\" -C \"${USERNAME}@$(hostname)-$(date +%F)\" -q"
}

# After generation, ensure ownership and perms
chown "$USERNAME":"$USERNAME" "${PRIV_KEY_PATH}"
chown "$USERNAME":"$USERNAME" "${PUB_KEY_PATH}"
chmod 600 "${PRIV_KEY_PATH}"
chmod 644 "${PUB_KEY_PATH}"

# Install public key into authorized_keys (append if not present)
touch "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"
chown "$USERNAME":"$USERNAME" "${AUTHORIZED_KEYS}"

# If pubkey not already in authorized_keys, append it
if ! grep -qs -F "$(cat "${PUB_KEY_PATH}")" "${AUTHORIZED_KEYS}"; then
  cat "${PUB_KEY_PATH}" >> "${AUTHORIZED_KEYS}"
  echo "Installed public key to ${AUTHORIZED_KEYS}"
else
  echo "Public key already present in ${AUTHORIZED_KEYS}"
fi

# Optionally add to sudo group
if [ "$ADD_SUDO" = true ]; then
  usermod -aG sudo "$USERNAME"
  echo "Added $USERNAME to group sudo"
fi

# Prepare private key output
PRIVATE_KEY_CONTENT="$(cat "${PRIV_KEY_PATH}")"

if [[ -n "$OUTFILE" ]]; then
  # Write private key to OUTFILE with secure perms
  umask 077
  echo "$PRIVATE_KEY_CONTENT" > "$OUTFILE"
  chmod 600 "$OUTFILE"
  echo "Private key written to: $OUTFILE (chmod 600)."
  echo "Ensure you move it off the server to a safe location and delete when no longer needed."
else
  # Print to stdout with clear markers so caller can capture it
  cat <<'EOF'

===== BEGIN PRIVATE KEY (copy everything between the markers) =====
EOF
  printf '%s\n' "$PRIVATE_KEY_CONTENT"
  cat <<'EOF'
===== END PRIVATE KEY =====

IMPORTANT:
- Save this private key immediately to a secure file (chmod 600).
- Do NOT leave this visible in logs or history.
- If you close this terminal without saving, you will not be able to retrieve the private key again from the server
  (unless you left the private file on disk under the user's ~/.ssh, but that would be insecure).
EOF
fi

# Print a short summary
cat <<EOF

Summary:
  user:             ${USERNAME}
  home:             ${HOME_DIR}
  ssh dir:          ${SSH_DIR}
  private key file: ${PRIV_KEY_PATH}
  public key file:  ${PUB_KEY_PATH}
  authorized_keys:  ${AUTHORIZED_KEYS}

Notes:
 - The generated key also remains in the user's ~/.ssh/ for server-side use.
 - If you used --out, that file contains the private key with chmod 600.
 - If you captured private key from stdout, move it to a secure path (chmod 600) and delete any temp copies.

EOF

exit 0
