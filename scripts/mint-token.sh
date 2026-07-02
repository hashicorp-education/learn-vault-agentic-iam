#!/usr/bin/env bash
#
# mint-token.sh: Example script to demonstrate  local signing-key path.
# Usage: ./mint-token.sh '<authorization_details JSON array>' # w/ RAR claim
#        ./mint-token.sh                                      # w/o RAR claim
#
# Signs an RFC 9068 at+jwt on-behalf-of token with the local ES256 key
# (ec-priv.pem) that the `local-obo-test` resource server profile trusts.
# Requires: openssl, jq, xxd.

set -euo pipefail

KEY="${EC_PRIV_KEY:-ec-priv.pem}"
ISS="${LOCAL_ISS:-https://hashicups-dev.us.auth0.com/local-test}"
SUB="${LOCAL_SUB:-auth0|danielle-human-0001}"
ACT="${LOCAL_ACT:-auth0|pr-reviewer-agent-0001}"
AUD="${LOCAL_AUD:-https://localhost:8200/v1}"
KID="${LOCAL_KID:-local-test-key-1}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
header=$(printf '%s' "{\"alg\":\"ES256\",\"typ\":\"at+jwt\",\"kid\":\"$KID\"}" | b64url)

# Build claims; add authorization_details only when an argument is supplied.
claims=$(jq -cn \
    --arg iss "$ISS" --arg sub "$SUB" --arg aud "$AUD" --arg act "$ACT" \
    --argjson now "$now" \
    '{iss:$iss, sub:$sub, aud:$aud, iat:$now, nbf:$now, exp:($now+3600),
    jti:("t"+($now|tostring)), act:{sub:$act}}')
if [ "${1:-}" != "" ]; then
    claims=$(jq -c --argjson ad "$1" '. + {authorization_details:$ad}' <<<"$claims")
fi
payload=$(printf '%s' "$claims" | b64url)

# ES256: openssl emits ASN.1/DER; JWS needs raw 64-byte r||s.
# Convert via asn1parse.
sig=$(printf '%s' "$header.$payload" |
    openssl dgst -sha256 -sign "$KEY" |
    openssl asn1parse -inform DER |
    awk -F: '/INTEGER/{gsub(/ /,"",$NF); printf "%064s", $NF}' |
    sed 's/ /0/g' | xxd -r -p | b64url)

printf '%s.%s.%s\n' "$header" "$payload" "$sig"
