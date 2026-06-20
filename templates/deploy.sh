#!/usr/bin/env bash
set -Eeuo pipefail

# Copy this template into a project as scripts/deploy.sh and replace the
# __PLACEHOLDER__ values before delivery.

PROJECT_NAME="${PROJECT_NAME:-__PROJECT_NAME__}"
PROJECT_SLUG="${PROJECT_SLUG:-__PROJECT_SLUG__}"
REPO_URL="${REPO_URL:-__REPO_URL__}"
BRANCH="${BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-}"
APP_USER="${APP_USER:-}"
SERVICE_NAME="${SERVICE_NAME:-}"
START_COMMAND="${START_COMMAND:-}"
MIGRATE_COMMAND="${MIGRATE_COMMAND:-}"
HEALTH_COMMAND="${HEALTH_COMMAND:-}"

LOCAL_MODE=0
YES=0
DOMAIN=""

usage() {
  cat <<USAGE
Usage:
  sudo bash scripts/deploy.sh --repo <git-url> [options]
  bash scripts/deploy.sh --local [options]

Options:
  --repo <url>          Git repository URL. Defaults to REPO_URL.
  --branch <name>       Branch to deploy. Defaults to main.
  --install-dir <path>  Install directory.
  --domain <name>       Domain name for docs/output. Reverse proxy is project-specific.
  --local               Install without root/systemd into the current user's home.
  --yes                 Skip interactive confirmation.
  -h, --help            Show this help.
USAGE
}

log() {
  printf '[%s] %s\n' "$PROJECT_SLUG" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

confirm() {
  if [[ "$YES" == "1" ]]; then
    return 0
  fi
  read -r -p "Continue deploying ${PROJECT_NAME} (${PROJECT_SLUG})? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "Deployment cancelled."
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        REPO_URL="${2:-}"
        shift 2
        ;;
      --branch)
        BRANCH="${2:-}"
        shift 2
        ;;
      --install-dir)
        INSTALL_DIR="${2:-}"
        shift 2
        ;;
      --domain)
        DOMAIN="${2:-}"
        shift 2
        ;;
      --local)
        LOCAL_MODE=1
        shift
        ;;
      --yes)
        YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

validate_config() {
  [[ "$PROJECT_SLUG" != "__PROJECT_SLUG__" ]] || die "Set PROJECT_SLUG before using this template."
  [[ "$PROJECT_NAME" != "__PROJECT_NAME__" ]] || die "Set PROJECT_NAME before using this template."
  [[ "$REPO_URL" != "__REPO_URL__" && -n "$REPO_URL" ]] || die "Set --repo or REPO_URL."
  [[ "$PROJECT_SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "PROJECT_SLUG must use lowercase ASCII letters, digits, and hyphens."

  if [[ -z "$INSTALL_DIR" ]]; then
    if [[ "$LOCAL_MODE" == "1" ]]; then
      INSTALL_DIR="${HOME}/.local/share/${PROJECT_SLUG}"
    else
      INSTALL_DIR="/opt/${PROJECT_SLUG}"
    fi
  fi

  APP_USER="${APP_USER:-$PROJECT_SLUG}"
  SERVICE_NAME="${SERVICE_NAME:-$PROJECT_SLUG}"
  assert_safe_install_dir
}

assert_safe_install_dir() {
  case "$INSTALL_DIR" in
    ""|"/"|"/opt"|"/usr"|"/var"|"/srv"|"$HOME"|"$HOME/"|"__INSTALL_DIR__")
      die "Refusing unsafe INSTALL_DIR: ${INSTALL_DIR}"
      ;;
  esac
}

as_root() {
  if [[ "$LOCAL_MODE" == "1" ]]; then
    "$@"
  elif [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_server_root() {
  if [[ "$LOCAL_MODE" == "0" && "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Server mode must run as root. Re-run with sudo, or use --local."
  fi
}

install_system_packages() {
  if [[ "$LOCAL_MODE" == "1" ]]; then
    log "Local mode: skipping apt package installation."
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl git sudo build-essential
}

ensure_app_user() {
  if [[ "$LOCAL_MODE" == "1" ]]; then
    mkdir -p "$(dirname "$INSTALL_DIR")"
    return 0
  fi

  if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
  fi
  mkdir -p "$INSTALL_DIR"
  chown -R "$APP_USER:$APP_USER" "$INSTALL_DIR"
}

run_in_install_dir() {
  (cd "$INSTALL_DIR" && "$@")
}

run_as_app() {
  if [[ "$LOCAL_MODE" == "1" ]]; then
    run_in_install_dir "$@"
  else
    local quoted_cmd quoted_dir
    printf -v quoted_cmd '%q ' "$@"
    printf -v quoted_dir '%q' "$INSTALL_DIR"
    sudo -H -u "$APP_USER" bash -lc "cd ${quoted_dir} && ${quoted_cmd}"
  fi
}

sync_repo() {
  log "Syncing repository ${REPO_URL} (${BRANCH}) into ${INSTALL_DIR}."
  mkdir -p "$INSTALL_DIR"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    run_as_app git fetch origin "$BRANCH"
    run_as_app git checkout -B "$BRANCH" "origin/${BRANCH}"
  else
    assert_safe_install_dir
    rm -rf "$INSTALL_DIR"
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    if [[ "$LOCAL_MODE" == "0" ]]; then
      chown -R "$APP_USER:$APP_USER" "$INSTALL_DIR"
    fi
  fi
}

install_project_dependencies() {
  if [[ -f "$INSTALL_DIR/package.json" ]]; then
    log "Detected Node.js project."
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
      [[ "$LOCAL_MODE" == "0" ]] || die "Install Node.js and npm, then re-run this script."
      apt-get install -y nodejs npm
    fi

    if [[ -f "$INSTALL_DIR/package-lock.json" ]]; then
      run_as_app npm ci
    else
      run_as_app npm install
    fi

    if run_as_app node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts.build ? 0 : 1)"; then
      run_as_app npm run build
    fi
  fi

  if [[ -f "$INSTALL_DIR/requirements.txt" || -f "$INSTALL_DIR/pyproject.toml" ]]; then
    log "Detected Python project."
    if ! command -v python3 >/dev/null 2>&1; then
      [[ "$LOCAL_MODE" == "0" ]] || die "Install Python 3, then re-run this script."
      apt-get install -y python3 python3-venv python3-pip
    elif [[ "$LOCAL_MODE" == "0" ]]; then
      apt-get install -y python3-venv python3-pip
    fi

    run_as_app python3 -m venv .venv
    if [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
      run_as_app .venv/bin/pip install -r requirements.txt
    fi
  fi
}

run_migrations() {
  if [[ -n "$MIGRATE_COMMAND" && "$MIGRATE_COMMAND" != "__MIGRATE_COMMAND__" ]]; then
    log "Running migration command."
    run_as_app bash -lc "$MIGRATE_COMMAND"
  fi
}

install_cli_menu() {
  local bin_dir cli_target cli_source

  if [[ "$LOCAL_MODE" == "1" ]]; then
    bin_dir="${HOME}/.local/bin"
  else
    bin_dir="/usr/local/bin"
  fi

  mkdir -p "$bin_dir"
  cli_target="${bin_dir}/${PROJECT_SLUG}"

  for candidate in \
    "$INSTALL_DIR/scripts/${PROJECT_SLUG}" \
    "$INSTALL_DIR/scripts/project-cli.sh" \
    "$INSTALL_DIR/templates/project-cli.sh"
  do
    if [[ -f "$candidate" ]]; then
      cli_source="$candidate"
      break
    fi
  done

  [[ -n "${cli_source:-}" ]] || die "No CLI menu script found. Add scripts/${PROJECT_SLUG} or scripts/project-cli.sh."

  sed \
    -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
    -e "s|__PROJECT_SLUG__|${PROJECT_SLUG}|g" \
    -e "s|__INSTALL_DIR__|${INSTALL_DIR}|g" \
    -e "s|__SERVICE_NAME__|${SERVICE_NAME}|g" \
    -e "s|__REPO_URL__|${REPO_URL}|g" \
    -e "s|__BRANCH__|${BRANCH}|g" \
    "$cli_source" > "$cli_target"

  chmod +x "$cli_target"
  log "Installed CLI menu: ${cli_target}"
}

install_systemd_service() {
  if [[ "$LOCAL_MODE" == "1" ]]; then
    log "Local mode: skipping systemd service installation."
    return 0
  fi

  if [[ -z "$START_COMMAND" || "$START_COMMAND" == "__START_COMMAND__" ]]; then
    log "START_COMMAND is not configured; skipping systemd service. Adapt this script before production delivery."
    return 0
  fi

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=${PROJECT_NAME}
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=-${INSTALL_DIR}/.env
ExecStart=/bin/bash -lc '${START_COMMAND}'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
}

run_health_check() {
  if [[ -n "$HEALTH_COMMAND" && "$HEALTH_COMMAND" != "__HEALTH_COMMAND__" ]]; then
    log "Running health check."
    run_in_install_dir bash -lc "$HEALTH_COMMAND"
  elif [[ "$LOCAL_MODE" == "0" ]] && systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl --no-pager --full status "$SERVICE_NAME" || true
  else
    log "No health check configured."
  fi
}

print_summary() {
  cat <<SUMMARY

Deployment complete.
Project:       ${PROJECT_NAME}
Slug command:  ${PROJECT_SLUG}
Install dir:   ${INSTALL_DIR}
Branch:        ${BRANCH}
Service:       ${SERVICE_NAME}
Domain:        ${DOMAIN:-not configured}

Next:
  ${PROJECT_SLUG}

SUMMARY
}

main() {
  parse_args "$@"
  validate_config
  require_server_root
  confirm
  install_system_packages
  ensure_app_user
  sync_repo
  install_project_dependencies
  run_migrations
  install_cli_menu
  install_systemd_service
  run_health_check
  print_summary
}

main "$@"
