set -euo pipefail

# data paths
readonly MARK_PATH=/var/lib/gitea/mark-initialized
readonly SECRET_PATH=/var/lib/gitea/secrets

# populate app.ini from environment
GITEA__security__SECRET_KEY_URI="file:${SECRET_PATH}/secret_key" \
GITEA__security__INTERNAL_TOKEN_URI="file:${SECRET_PATH}/internal_token" \
GITEA__oauth2__JWT_SECRET_URI="file:${SECRET_PATH}/jwt_secret" \
/usr/local/bin/docker-setup.sh

# initialize gitea if uninitialized
if [[ ! -f "$MARK_PATH" ]]; then
  # load credentials from secrets
  name="$(cat /run/secrets/gitea-admin-name)"
  pass="$(cat /run/secrets/gitea-admin-pass)"

  # generate secrets
  mkdir -p "$SECRET_PATH"
  for secret in SECRET_KEY INTERNAL_TOKEN JWT_SECRET; do
    gitea generate secret "$secret" | install -m 400 /dev/stdin "$SECRET_PATH/${secret,,}"
  done

  # initialize database
  gitea migrate

  # create admin user
  gitea admin user create --admin --must-change-password \
    --email "${name}@localhost" --username "${name}" --password "${pass}"

  # mark initialized
  touch "$MARK_PATH"
fi

# execute gitea or custom command if present
if (( $# == 0 ))
then exec /usr/local/bin/gitea -c "$GITEA_APP_INI" web
else exec "$@"
fi