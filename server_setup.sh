# https://github.com/suppaduppax/server-setup
# -------------------------------------------
# Script to automate basic server setup such including
# - tmuxrc
# - nanorc
# - static ip address
#
GENERATED_HEADER="# Generated by $(basename ${0})"
# .nanorc
NANORC_FILE="${HOME}/.nanorc"
NANORC_CONTENT="set tabstospaces 1\nset tabsize 2"

# tmuxrc
TMUXRC_DIR="${HOME}/tmuxrc"
TMUXRC_GIT="https://github.com/suppaduppax/tmuxrc"

# interfaces and ip address
DEFAULT_CIDR="24"
INTERFACES_PATH="/etc/network/interfaces"
INTERFACES_CONTENT="${GENERATED_HEADER}
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source /etc/network/interfaces.d/*"
IF_PATH="/etc/network/interfaces.d"
IF_FILE="$(ip route | grep default | sed -e 's/^.*dev.//' -e 's/.proto.*//' -e 's/.onlink.*//' | awk '{$1=$1};1')"
IF_GATEWAY=$(ip -4 route show default | grep -o "[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*")
IF_NAMESERVER=$(cat /etc/resolv.conf | grep -o "[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*")
IF_CIDR="24"

# yes-no confirmation prompt
confirm() {
  while true; do
    echo -n "${1} ["
    if [[ "${2}" = "y" ]]; then
      echo -n "Y"
    else
      echo -n "y"
    fi
    echo -n "/"
    if [[ "${2}" = "n" ]]; then
      echo -n "N"
    else
      echo -n "n"
    fi

    echo -n "] "
    read -n 1 YESNO
    echo

    if [[ "${YESNO}" = "y" ]]; then
      return 1
    fi

    if [[ "${YESNO}" = "n" ]]; then
      return 0
    fi

    if [ -z "${YESNO}" ] && [[ "${2}" = "y" ]]; then
      return 1
    fi

    if [ -z "${YESNO}" ] && [[ "${2}" = "n" ]]; then
      return 0
    fi
  done
}

setup_git() {
  if dpkg -s "git" &>/dev/null; then
    echo "Git already installed..."
  else
    sudo apt install -y git
  fi
}

setup_nanorc() {
  if [ -f "${NANORC_FILE}" ]; then
    confirm "File '.nanorc' exists. Overwrite?" "y"
    if [ $? -eq 1 ] ; then
      echo "Overwriting..."
      echo -e "${NANORC_CONTENT}" > ${NANORC_FILE}
    else
      echo "Skipping..."
    fi
  else
    echo "Creating '.nanorc' file..."
    echo -e "${NANORC_CONTENT}" > ${NANORC_FILE}
  fi
}

setup_tmuxrc() {
  if [ -d "${TMUXRC_DIR}" ]; then
    echo "tmuxrc repo is already cloned"
  else
    # clone tmuxrc repo
    if ! dpkg -s "git" &>/dev/null; then
      echo "git is not installed. installing..."9
      setup_git
    fi
    git clone "${TMUXRC_GIT}"
  fi

  ${HOME}/tmuxrc/install.sh
}

setup_ip() {
  . /etc/os-release

  echo "Setting up host ip..."
  while true; do
    read -p "Enter new ip: " -e NEW_IP
    OCTET=$(echo "${NEW_IP}" | grep -oe "[0-9]*[.][0-9]*[.][0-9]*[.][0-9]*")
    INVALID_CHAR=$(echo "${NEW_IP}" | grep -oe "[^0-9./]")
    if [ -z "${OCTET}" ]; then
      echo "Invalid ip: '${NEW_IP}'"
      continue
    fi
    if [ ! -z "${INVALID_CHAR}" ] ; then
      echo "Invalid character: '${INVALID_CHAR}'"
      continue
    fi
    IF_ADDRESS="${NEW_IP}"
    IF_CIDR=$(echo ${NEW_IP} | grep -oe "/[0-9]*")

    if [ -z "${IF_CIDR}" ]; then
      while true; do
        read -p "Enter CIDR [24]: " -e IF_CIDR
        if [ -z "${IF_CIDR}" ]; then
          IF_CIDR="${DEFAULT_CIDR}"
        fi
        INVALID_CHAR=$(echo "${IF_CIDR}" | grep -oe "[^0-9]*")
        IF_CIDR=$(echo "${IF_CIDR}" | grep -oe "[0-9]*")
        if [ ! -z "${INVALID_CHAR}" ] ; then
          echo "Invalid character: '${INVALID_CHAR}'"
          continue
        fi
        if [ -z "${IF_CIDR}" ]; then
          echo "Invalid CIDR: '${IF_CIDR}'"
          continue
        fi
        IF_ADDRESS="${NEW_IP}/${IF_CIDR}"
        break
      done
    fi

    confirm "Use ip address: '${IF_ADDRESS}'" "n"
    if [ $? -eq 1 ]; then
      break
    fi
  done
  IF_CONTENT="${GENERATED_HEADER}
auto ens192
iface ens192 inet static
  address ${IF_ADDRESS}
  gateway ${IF_GATEWAY}
  nameserver ${IF_NAMESERVER}
"

  if [ $ID = "debian" ]; then
    setup_ip_debian
  fi
}

setup_ip_debian() {
  echo "Writing '${INTERFACES_PATH}'..."
  echo "${INTERFACES_CONTENT}" | sudo tee "${INTERFACES_PATH}" >/dev/null
  echo "Using path '${IF_PATH}' and file '${IF_FILE}'"
  echo "Writing '${IF_PATH}/${IF_FILE}'..."
  echo "${IF_CONTENT}" | sudo tee "${IF_PATH}/${IF_FILE}" >/dev/null

  confirm "Restart network service? (You will be disconnected from ssh)" "y"
  if [ $? -eq 1 ]; then
    sudo systemctl restart networking
  fi
}

main() {
  setup_nanorc
  setup_git
  setup_tmuxrc
  setup_ip
}

main
