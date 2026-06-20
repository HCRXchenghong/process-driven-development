#!/usr/bin/env bash
set -Eeuo pipefail

# Copy this template into a project as scripts/project-cli.sh, adapt the hook
# commands, then let scripts/deploy.sh install it as /usr/local/bin/<slug>.

PROJECT_NAME="${PROJECT_NAME:-__PROJECT_NAME__}"
PROJECT_SLUG="${PROJECT_SLUG:-__PROJECT_SLUG__}"
INSTALL_DIR="${INSTALL_DIR:-__INSTALL_DIR__}"
SERVICE_NAME="${SERVICE_NAME:-__SERVICE_NAME__}"
REPO_URL="${REPO_URL:-__REPO_URL__}"
BRANCH="${BRANCH:-__BRANCH__}"

HEALTH_COMMAND="${HEALTH_COMMAND:-}"
ADMIN_COMMAND="${ADMIN_COMMAND:-}"
BACKUP_COMMAND="${BACKUP_COMMAND:-}"
RESTORE_COMMAND="${RESTORE_COMMAND:-}"
UPDATE_COMMAND="${UPDATE_COMMAND:-}"

log() {
  printf '[%s] %s\n' "$PROJECT_SLUG" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

pause() {
  printf '\n'
  read -r -p "Press Enter to continue..." _
}

as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

service_exists() {
  command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service "${SERVICE_NAME}.service" --no-legend 2>/dev/null | grep -q "^${SERVICE_NAME}\\.service"
}

service_action() {
  local action="$1"
  if service_exists; then
    as_root systemctl "$action" "$SERVICE_NAME"
  else
    log "No systemd service named ${SERVICE_NAME}; adapt service_action for this project."
  fi
}

show_status() {
  if service_exists; then
    systemctl --no-pager --full status "$SERVICE_NAME" || true
  else
    log "Install directory: ${INSTALL_DIR}"
    [[ -d "$INSTALL_DIR" ]] && (cd "$INSTALL_DIR" && git status --short --branch || true)
  fi

  if [[ -n "$HEALTH_COMMAND" && "$HEALTH_COMMAND" != "__HEALTH_COMMAND__" ]]; then
    (cd "$INSTALL_DIR" && bash -lc "$HEALTH_COMMAND") || true
  fi
}

show_logs() {
  if service_exists; then
    as_root journalctl -u "$SERVICE_NAME" -n 200 --no-pager
  else
    log "No systemd logs found. Adapt show_logs for this project's runtime."
  fi
}

update_project() {
  if [[ -n "$UPDATE_COMMAND" && "$UPDATE_COMMAND" != "__UPDATE_COMMAND__" ]]; then
    (cd "$INSTALL_DIR" && bash -lc "$UPDATE_COMMAND")
    return 0
  fi

  if [[ -x "$INSTALL_DIR/scripts/deploy.sh" ]]; then
    as_root bash "$INSTALL_DIR/scripts/deploy.sh" \
      --repo "$REPO_URL" \
      --branch "$BRANCH" \
      --install-dir "$INSTALL_DIR" \
      --yes
    return 0
  fi

  die "No update command configured. Add scripts/deploy.sh or set UPDATE_COMMAND."
}

admin_menu() {
  while true; do
    clear || true
    cat <<MENU
${PROJECT_NAME} admin management

1. Create admin
2. List admins
3. Reset admin credentials
4. Enable admin
5. Disable admin
6. Delete admin
0. Back
MENU
    read -r -p "Choose: " choice
    case "$choice" in
      1) run_admin_hook create; pause ;;
      2) run_admin_hook list; pause ;;
      3) run_admin_hook reset; pause ;;
      4) run_admin_hook enable; pause ;;
      5) run_admin_hook disable; pause ;;
      6) run_admin_hook delete; pause ;;
      0) return 0 ;;
      *) log "Invalid choice."; pause ;;
    esac
  done
}

run_admin_hook() {
  local action="$1"
  if [[ -z "$ADMIN_COMMAND" || "$ADMIN_COMMAND" == "__ADMIN_COMMAND__" ]]; then
    log "Admin management is not wired yet. Configure ADMIN_COMMAND for this project."
    return 0
  fi
  (cd "$INSTALL_DIR" && bash -lc "$ADMIN_COMMAND $action")
}

backup_menu() {
  while true; do
    clear || true
    cat <<MENU
${PROJECT_NAME} backup and restore

1. Create backup
2. Restore backup
0. Back
MENU
    read -r -p "Choose: " choice
    case "$choice" in
      1) run_backup_hook backup; pause ;;
      2) run_backup_hook restore; pause ;;
      0) return 0 ;;
      *) log "Invalid choice."; pause ;;
    esac
  done
}

run_backup_hook() {
  local action="$1"
  local command=""
  if [[ "$action" == "backup" ]]; then
    command="$BACKUP_COMMAND"
  else
    command="$RESTORE_COMMAND"
  fi

  if [[ -z "$command" || "$command" == "__BACKUP_COMMAND__" || "$command" == "__RESTORE_COMMAND__" ]]; then
    log "${action} is not wired yet. Configure the backup/restore hook for this project."
    return 0
  fi
  (cd "$INSTALL_DIR" && bash -lc "$command")
}

edit_environment() {
  local env_file="${INSTALL_DIR}/.env"
  mkdir -p "$INSTALL_DIR"
  touch "$env_file"
  "${EDITOR:-nano}" "$env_file"
}

delete_project() {
  printf '\nThis will uninstall %s from this machine.\n' "$PROJECT_NAME"
  printf 'It will remove the service, install directory, and CLI command owned by this project.\n'
  read -r -p "Type ${PROJECT_SLUG} to continue: " typed
  [[ "$typed" == "$PROJECT_SLUG" ]] || die "Confirmation did not match."

  read -r -p "Create backup first if BACKUP_COMMAND is configured? [Y/n] " backup_answer
  if [[ "$backup_answer" != "n" && "$backup_answer" != "N" ]]; then
    run_backup_hook backup || true
  fi

  if service_exists; then
    as_root systemctl stop "$SERVICE_NAME" || true
    as_root systemctl disable "$SERVICE_NAME" || true
    as_root rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    as_root systemctl daemon-reload || true
  fi

  case "$INSTALL_DIR" in
    ""|"/"|"/opt"|"$HOME"|"$HOME/"|"__INSTALL_DIR__")
      die "Refusing to remove unsafe INSTALL_DIR: ${INSTALL_DIR}"
      ;;
  esac

  as_root rm -rf "$INSTALL_DIR"
  as_root rm -f "/usr/local/bin/${PROJECT_SLUG}"
  rm -f "${HOME}/.local/bin/${PROJECT_SLUG}" 2>/dev/null || true
  log "Uninstalled ${PROJECT_NAME}."
}

main_menu() {
  while true; do
    clear || true
    cat <<MENU
${PROJECT_NAME} management

1. Status and health
2. Start
3. Stop
4. Restart
5. Logs
6. Update project
7. Manage admins
8. Backup and restore
9. Edit environment
10. Delete/uninstall project
0. Exit
MENU
    read -r -p "Choose: " choice
    case "$choice" in
      1) show_status; pause ;;
      2) service_action start; pause ;;
      3) service_action stop; pause ;;
      4) service_action restart; pause ;;
      5) show_logs; pause ;;
      6) update_project; pause ;;
      7) admin_menu ;;
      8) backup_menu ;;
      9) edit_environment; pause ;;
      10) delete_project; pause ;;
      0) exit 0 ;;
      *) log "Invalid choice."; pause ;;
    esac
  done
}

main_menu "$@"
