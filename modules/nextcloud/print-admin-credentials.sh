print-admin-credentials() {
  podman secret inspect --showsecret -- "nextcloud-admin-name" | jq -r '.[0].SecretData'
  podman secret inspect --showsecret -- "nextcloud-admin-pass" | jq -r '.[0].SecretData'
}