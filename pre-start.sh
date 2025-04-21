#!/bin/bash
#title           :pre-start.sh
#description     :Starter Script to lauch service locally with docker
#author          :thluon
#date            :2025-04-20
#version         :0.1.0
#usage           :pre-start.sh -h
#notes           :Require openssl for auto generate-password
#==============================================================================
usage() {
  echo "Usage: $0 [-l]"
  echo "  -l      Enable logging"
  exit 1
}
EXPECTING_MYSQL_DATABASES=2
LOGGING_ENABLED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
  -l)
    LOGGING_ENABLED=true
    shift
    ;;
  -*)
    usage
    ;;
  *)
    break
    ;;
  esac
done
## Checking requirements
preflight_check() {
  if [ ! -f ".env" ]; then
    echo ".env file does not exist"
    exit 1
  fi
}
# update_env <ENV_KEY> <ENV_VAL>
# Updates or adds an environment variable in the .env file.
# Arguments:
#   ENV_KEY - The key/name of the environment variable.
#   ENV_VAL - The value to assign to the environment variable.
update_env() {
  ENV_KEY=$1
  ENV_VAL=$2
  if grep -q "^${ENV_KEY}=" .env; then
    sed -i "s#^${ENV_KEY}=.*#${ENV_KEY}=${ENV_VAL}#" .env
  else
    echo "${ENV_KEY}=${ENV_VAL}" >>.env
  fi
  if [ "$LOGGING_ENABLED" = true ]; then
    echo "Updated [${ENV_KEY}=${ENV_VAL}] to .env"
  fi
}
# Is the bash run in wsl2 ?
is_wsl2() {
  grep -q "microsoft" /proc/version && grep -q "WSL2" /proc/sys/kernel/osrelease
}
# Logging
log() {
  if [ "${LOGGING_ENABLED}" = true ]; then
    echo $1
  fi
}
# ask_yes_no <question>
# Returns 0 for yes, 1 for no
ask_yes_no() {
  local prompt="$1"
  while true; do
    read -p "$prompt (Y[es]/N[o]): " input
    case "$input" in
    [Yy] | [Yy][Ee][Ss]) return 0 ;;
    [Nn] | [Nn][Oo]) return 1 ;;
    *) echo "Please answer Yes or No." ;;
    esac
  done
}
generate_template() {
  dir=$1
  templates=()
  while IFS= read -r -d '' template; do
    templates+=("$template")
  done < <(find "$dir" -maxdepth 1 -type f -name "*.template" -print0)
  log "Found ${#templates[@]} template(s) in ${dir}."
  for template in "${templates[@]}"; do
    required_vars=$(grep -o '\${\([^}]*\)}' "$template" | sed 's/${\([^}]*\)}/\1/' | sort | uniq)
    for var in $required_vars; do
      if [ -z "${!var}" ]; then
        echo "Error: [$var] is not set"
        exit 1
      fi
    done
    target="${template%.template}"
    envsubst <"$template" >"$target"
    log "Generated ${target}"
  done
}
preflight_check
MYSQL_DATABASES=./databases/mysql/
read -p "Mysql databases location (default: ./databases/mysql/) ?" input
MYSQL_DATABASES=${input:-$MYSQL_DATABASES}
if [[ ! -d "${MYSQL_DATABASES}" ]]; then
  echo "WARNIG: ${INIT_TEMPLATE_DIR} no such file or directory!\nPlease try again"
  exit 1
fi
# Getting mysql
MYSQL_DATABASE_DIRS=$(find ./databases/mysql -maxdepth 1 -type d ! -path ./databases/mysql)
MYSQL_DATABASE_DIRS_COUNT=$(echo "$MYSQL_DATABASE_DIRS" | wc -l)
log "Found: ${MYSQL_DATABASE_DIRS_COUNT}"
for dir in $MYSQL_DATABASE_DIRS; do
  log "- ${dir}"
done

if [ "$MYSQL_DATABASE_DIRS_COUNT" != "$EXPECTING_MYSQL_DATABASES" ]; then
  echo "Mismatch in database count. Expected $EXPECTING_MYSQL_DATABASES, but found $MYSQL_DATABASE_DIRS_COUNT."
  exit 1
fi
if ! grep -q "^JWT_SECRET=" .env; then
  echo "JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n')" >>.env
  echo "WARNING! No JWT_SECRET, generated one!"
else
  read -p "New Jwt Secret?(Yes/No) (default: No [require openssl])" input
  input=${input:-No}
  if [[ "$input" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
    jwt=$(openssl rand -base64 32 | tr -d "\n")
    update_env "JWT_SECRET" "${jwt}"
    log "Generated JWT_SECRET: $JWT_SECRET"
  else
    log "Using existing JWT secret."
  fi
fi

# Soure env
set -a
. .env
set +a
# Genrating template
for dir in $MYSQL_DATABASE_DIRS; do
  if [ -d "$dir/init" ]; then
    generate_template "${dir}/init"
  else
    echo "Cannot locate ${dir}/init!"
    exit 1
  fi
done
# There is a bug related to docker with wsl2 causing high vmemwsl usage without releasing.
# Instead of directly calling docker compose inside WSL, use cmd.exe instead.
# Theoretically, it should make no different if using docker wsl container, but in reality this make significant different.
# Hypotheiscally, this is wsl2 kernel issue.
if is_wsl2; then
  cmd.exe /c "docker-compose up -d"
else
  docker compose up -d
fi
