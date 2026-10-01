#!/usr/bin/env bash
#
# check-requirements.sh
#
# Checks the prerequisites needed to deploy QSL Card Creator on Debian/Ubuntu,
# shows the installed versions, warns about incompatible versions and offers to
# install whatever is missing (always asking for confirmation first).
#
# Checked items:
#   git, curl, ca-certificates, Node.js (^20.19 or >=22.12), npm, Apache (>=2.4),
#   certbot, python3-certbot-apache and the Apache modules
#   proxy, proxy_http, rewrite and ssl.
#
# Usage:
#   ./check-requirements.sh [options]
#
# Options:
#   -c, --check-only   only report, never install anything
#   -y, --yes          do not ask for confirmation (non-interactive)
#   -n, --dry-run      show the commands that would run, without running them
#   -h, --help         show this help
#
# Exit status: 0 when every requirement is satisfied, 1 otherwise.

PATH="$PATH:/usr/sbin:/sbin"

NODE_MIN_20="20.19.0"
NODE_MIN_22="22.12.0"
APACHE_MIN="2.4.0"
NODESOURCE_URL="https://deb.nodesource.com/setup_22.x"
APACHE_MODULES=(proxy proxy_http rewrite ssl)

CHECK_ONLY=0
ASSUME_YES=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    -c | --check-only) CHECK_ONLY=1 ;;
    -y | --yes) ASSUME_YES=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED="" C_GREEN="" C_YELLOW="" C_BOLD="" C_RESET=""
fi

title() { printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }
row() { printf '  %-28s %-9s %s\n' "$1" "$2" "$3"; }
row_ok() { row "$1" "${C_GREEN}[ OK ]${C_RESET}" "$2"; }
row_missing() { row "$1" "${C_RED}[MISS]${C_RESET}" "$2"; }
row_old() { row "$1" "${C_YELLOW}[WARN]${C_RESET}" "$2"; }

# --------------------------------------------------------------- helpers ----

have() { command -v "$1" > /dev/null 2>&1; }

extract_version() { grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1; }

# ver_ge A B -> true when version A >= version B
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]; }

# Node.js is compatible with ^20.19 or >=22.12
node_ok() {
  local major=${1%%.*}
  if [ "$major" -eq 20 ]; then
    ver_ge "$1" "$NODE_MIN_20"
  elif [ "$major" -ge 22 ]; then
    ver_ge "$1" "$NODE_MIN_22"
  else
    return 1
  fi
}

pkg_version() { dpkg-query -W -f='${Version}' "$1" 2> /dev/null; }
pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2> /dev/null | grep -q "install ok installed"; }

HAS_APT=0
if have apt-get && have dpkg-query; then HAS_APT=1; fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then SUDO="sudo"; else SUDO="none"; fi
fi

confirm() {
  local question=$1 answer
  if [ "$ASSUME_YES" -eq 1 ]; then
    echo "$question [y/N] y (--yes)"
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "$question [y/N] n (not interactive, use --yes to accept)"
    return 1
  fi
  read -r -p "$question [y/N] " answer
  case "$answer" in
    y | Y | yes | YES | s | S | sim | SIM) return 0 ;;
    *) return 1 ;;
  esac
}

# run CMD...  -> prints the command, runs it unless --dry-run
run() {
  echo "  + $*"
  [ "$DRY_RUN" -eq 1 ] && return 0
  "$@"
}

as_root() {
  if [ "$SUDO" = "sudo" ]; then run sudo "$@"; else run "$@"; fi
}

# ---------------------------------------------------------------- checks ----

MISSING_PKGS=()    # apt packages to install
NODE_PROBLEM=""    # "", missing, old or npm
MODULES_MISSING=() # Apache modules to enable
WARNINGS=()        # incompatibility notifications
PROBLEMS=0

# check_tool LABEL COMMAND APT_PACKAGE [MINIMUM_VERSION]
check_tool() {
  local label=$1 cmd=$2 pkg=$3 min=${4:-} version
  if ! have "$cmd"; then
    row_missing "$label" "not installed"
    MISSING_PKGS+=("$pkg")
    PROBLEMS=$((PROBLEMS + 1))
    return
  fi
  case "$cmd" in
    apache2) version=$(apache2 -v 2>&1 | extract_version) ;;
    *) version=$("$cmd" --version 2>&1 | head -n 1 | extract_version) ;;
  esac
  if [ -n "$min" ] && [ -n "$version" ] && ! ver_ge "$version" "$min"; then
    row_old "$label" "$version (needs >= $min)"
    WARNINGS+=("$label $version is older than the required $min.")
    MISSING_PKGS+=("$pkg")
    PROBLEMS=$((PROBLEMS + 1))
  else
    row_ok "$label" "${version:-installed}"
  fi
}

# check_pkg LABEL APT_PACKAGE
check_pkg() {
  local label=$1 pkg=$2
  if [ "$HAS_APT" -ne 1 ]; then
    row_old "$label" "cannot check (dpkg not found)"
    return
  fi
  if pkg_installed "$pkg"; then
    row_ok "$label" "$(pkg_version "$pkg")"
  else
    row_missing "$label" "not installed"
    MISSING_PKGS+=("$pkg")
    PROBLEMS=$((PROBLEMS + 1))
  fi
}

check_node() {
  local version
  if ! have node; then
    row_missing "Node.js" "not installed (needs ^20.19 or >=22.12)"
    NODE_PROBLEM="missing"
    PROBLEMS=$((PROBLEMS + 1))
  else
    version=$(node -v 2>&1 | extract_version)
    if node_ok "$version"; then
      row_ok "Node.js" "$version"
    else
      row_old "Node.js" "$version (needs ^20.19 or >=22.12)"
      WARNINGS+=("Node.js $version is incompatible: this project needs ^20.19 or >=22.12.")
      NODE_PROBLEM="old"
      PROBLEMS=$((PROBLEMS + 1))
    fi
  fi

  if have npm; then
    row_ok "npm" "$(npm -v 2>&1 | extract_version)"
  else
    row_missing "npm" "not installed"
    [ -z "$NODE_PROBLEM" ] && NODE_PROBLEM="npm"
    PROBLEMS=$((PROBLEMS + 1))
  fi
}

check_modules() {
  local mod loaded
  MODULES_MISSING=()
  if ! have apache2ctl; then
    row_old "Apache modules" "cannot check until Apache is installed"
    return
  fi
  loaded=$(apache2ctl -M 2> /dev/null)
  for mod in "${APACHE_MODULES[@]}"; do
    if grep -q "${mod}_module" <<< "$loaded"; then
      row_ok "Apache module: $mod" "enabled"
    else
      row_missing "Apache module: $mod" "not enabled"
      MODULES_MISSING+=("$mod")
      PROBLEMS=$((PROBLEMS + 1))
    fi
  done
}

run_checks() {
  MISSING_PKGS=()
  NODE_PROBLEM=""
  WARNINGS=()
  PROBLEMS=0

  title "Checking requirements"
  check_tool "git" git git
  check_tool "curl" curl curl
  check_pkg "ca-certificates" ca-certificates
  check_node
  check_tool "Apache (apache2)" apache2 apache2 "$APACHE_MIN"
  check_tool "certbot" certbot certbot
  check_pkg "python3-certbot-apache" python3-certbot-apache
  check_modules
}

show_warnings() {
  [ "${#WARNINGS[@]}" -eq 0 ] && return
  title "${C_YELLOW}!! Incompatible versions found${C_RESET}"
  local w
  for w in "${WARNINGS[@]}"; do
    echo "  ${C_YELLOW}!${C_RESET} $w"
  done
}

# ------------------------------------------------------------------ main ----

echo "${C_BOLD}QSL Card Creator - requirements check${C_RESET}"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  echo "System: $(. /etc/os-release && echo "${PRETTY_NAME:-unknown}")"
fi
[ "$DRY_RUN" -eq 1 ] && echo "${C_YELLOW}Dry run: nothing will be changed.${C_RESET}"

run_checks
show_warnings

if [ "$PROBLEMS" -eq 0 ]; then
  title "${C_GREEN}All requirements are satisfied.${C_RESET}"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  title "${C_RED}$PROBLEMS requirement(s) missing or incompatible.${C_RESET}"
  echo "Run the script again without --check-only to install them."
  exit 1
fi

if [ "$HAS_APT" -ne 1 ]; then
  title "${C_RED}Automatic installation is only supported on Debian/Ubuntu (apt).${C_RESET}"
  echo "Install the items above manually, then run this script again."
  exit 1
fi

if [ "$SUDO" = "none" ]; then
  title "${C_RED}Root privileges are required to install packages.${C_RESET}"
  echo "Run this script as root or install sudo."
  exit 1
fi

# --- 1. apt packages -------------------------------------------------------

# Node.js is handled separately (NodeSource), so it never goes through here.
if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
  # remove duplicates
  mapfile -t MISSING_PKGS < <(printf '%s\n' "${MISSING_PKGS[@]}" | awk '!seen[$0]++')
  title "System packages"
  echo "  To install or update: ${MISSING_PKGS[*]}"
  if confirm "Install these packages with apt?"; then
    as_root apt-get update
    as_root apt-get install -y "${MISSING_PKGS[@]}"
  else
    echo "  Skipped."
  fi
fi

# --- 2. Node.js + npm ------------------------------------------------------

if [ -n "$NODE_PROBLEM" ]; then
  title "Node.js and npm"
  case "$NODE_PROBLEM" in
    missing) echo "  Node.js is not installed." ;;
    old) echo "  The installed Node.js is too old for this project." ;;
    npm) echo "  Node.js is installed but npm is not." ;;
  esac
  echo "  The recommended fix is the official NodeSource repository (Node.js 22 LTS,"
  echo "  npm included). It downloads and runs the setup script from:"
  echo "    $NODESOURCE_URL"
  echo "  and installs the 'nodejs' package, replacing the distribution's Node.js."
  if confirm "Install Node.js 22 from NodeSource?"; then
    if [ "$SUDO" = "sudo" ]; then
      run sudo -E bash -c "curl -fsSL $NODESOURCE_URL | bash -"
    else
      run bash -c "curl -fsSL $NODESOURCE_URL | bash -"
    fi
    as_root apt-get install -y nodejs
  else
    echo "  Skipped. You can also use nvm: https://github.com/nvm-sh/nvm"
  fi
fi

# --- 3. Apache modules -----------------------------------------------------

if have apache2ctl; then
  MODULES_MISSING=()
  loaded=$(apache2ctl -M 2> /dev/null)
  for mod in "${APACHE_MODULES[@]}"; do
    grep -q "${mod}_module" <<< "$loaded" || MODULES_MISSING+=("$mod")
  done
  if [ "${#MODULES_MISSING[@]}" -gt 0 ]; then
    title "Apache modules"
    echo "  To enable: ${MODULES_MISSING[*]} (Apache will be restarted)"
    if confirm "Enable these Apache modules?"; then
      as_root a2enmod "${MODULES_MISSING[@]}"
      as_root systemctl restart apache2 \
        || echo "  ${C_YELLOW}Could not restart Apache. Run: sudo systemctl restart apache2${C_RESET}"
    else
      echo "  Skipped."
    fi
  fi
fi

# --- final check -----------------------------------------------------------

if [ "$DRY_RUN" -eq 1 ]; then
  title "Dry run finished: nothing was changed."
  exit 1
fi

hash -r
run_checks
show_warnings

if [ "$PROBLEMS" -eq 0 ]; then
  title "${C_GREEN}All requirements are satisfied. You can continue with the installation.${C_RESET}"
  exit 0
fi

title "${C_RED}$PROBLEMS requirement(s) still missing or incompatible.${C_RESET}"
echo "Fix the items above and run this script again."
exit 1
