#!/bin/bash
set -eux

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

RANDOMNESS=$(openssl rand -base64 29 | tr -d "=+/" | cut -c1-25)
echo "creating id-${RANDOMNESS}"
mkdir "id-${RANDOMNESS}"


# you'll need to tell OSX security that you trust artifactory plugin binary
echo "killing vault processes"
pkill -9 vault || true && pkill vault || true
bash -c "vault server -dev -dev-root-token-id=root > /dev/null &"

echo "pausing for Vault init..."
sleep 5

export VAULT_ROOT_TOKEN="root"
export VAULT_TOKEN=$VAULT_ROOT_TOKEN
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_SKIP_VERIFY=true
vault login root
vault token lookup | grep policies


sleep 2


declare -a StringArray=("bar" "baz" "foo" "qux")
 
# Iterate the string array using for loop
for val in ${StringArray[@]}; do
   echo $val
   vault policy write $val - << EOF
# Dev servers have version 2 of KV secrets engine mounted by default, so will
# need these paths to grant permissions:
path "secret/$val/*" {
  capabilities = ["create", "update"]
}

path "secret/$val" {
  capabilities = ["read"]
}
EOF

done

   vault policy write $val - << EOF
# Mount secrets engines
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}

# Work with pki secrets engine
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}



EOF

# https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine#lab-setup

vault secrets enable pki

vault write -field=certificate pki/root/generate/internal \
     common_name="example.com" \
     issuer_name="root-2022" \
     ttl=87600h > root_2022_ca.crt


vault write pki/roles/2022-servers allow_any_name=true

vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"


vault secrets enable -path=pki_int pki

vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
     common_name="example.com Intermediate Authority" \
     issuer_name="example-dot-com-intermediate" \
     | jq -r '.data.csr' > pki_intermediate.csr


vault write -format=json pki/root/sign-intermediate \
     issuer_ref="root-2022" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > intermediate.cert.pem


vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

vault write pki_int/roles/example-dot-com \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="720h"


vault write pki_int/issue/example-dot-com common_name="test.example.com" ttl="24h"



# Make this work with Vault
# consul-template -template="all-pki.tpl:all-pki.txt" -once