update:
    bws run 'helmfile deps'

deploy ARGS='--output simple -i':
    bws run 'helmfile apply {{ARGS}}'

diff ARGS='':
    bws run 'helmfile diff --output dyff {{ARGS}}'

cleanuppods:
    kubectl get pods --no-headers | grep -v Running  | awk '{print $1}' | xargs kubectl delete pod
    
pgrestart:
    kubectl patch postgrescluster/postgres  --type merge --patch '{"spec":{"metadata":{"annotations":{"restarted":"'"$(date)"'"}}}}'

goatchat-register:
    bws run 'curl -v -H '\"'Authorization: SharedSecret $GOATCHAT_REGISTRATION_ADMIN_API_SHARE_SECRET'\"' \
        -H "Content-Type: application/json" \
        -d '\''{"max_usage": 0, "expiration_date": "2026-01-01"}'\'' \
        https://goatchat.ca/gate/api/token'
goatchat-register-review:
    bws run 'curl -v -H '\"'Authorization: SharedSecret $GOATCHAT_REGISTRATION_ADMIN_API_SHARE_SECRET'\"' \
        -H "Content-Type: application/json" \
        https://goatchat.ca/gate/api/token' | jq
