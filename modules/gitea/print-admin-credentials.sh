print-admin-credentials() {
  podman secret inspect --showsecret -- "gitea-admin-name" | jq -r '.[0].SecretData'
  podman secret inspect --showsecret -- "gitea-admin-pass" | jq -r '.[0].SecretData'
}