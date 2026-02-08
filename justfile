update:
    bws run 'helmfile deps'

deploy ARGS='':
    bws run 'helmfile apply --output simple --skip-deps {{ARGS}}'

diff ARGS='':
    bws run 'helmfile diff --output dyff  --skip-deps {{ARGS}}'

cleanuppods:
    #!/bin/bash
    kubectl get pods --all-namespaces | grep -v Running | awk '{print $1, $2}' | tail -n +2 | while read namespace pod; do
       kubectl delete pod "$pod" --namespace "$namespace"
    done

cleanupjobs:
    #!/bin/bash
    kubectl get jobs --all-namespaces | grep -v Running | awk '{print $1, $2}' | tail -n +2 | while read namespace job; do
       kubectl delete job "$job" --namespace "$namespace"
    done

    
pgrestart:
    kubectl patch postgrescluster/postgres  --type merge --patch '{"spec":{"metadata":{"annotations":{"restarted":"'"$(date)"'"}}}}'


talos-upgrade VERSION NODE:
    talosctl upgrade  \
      --image factory.talos.dev/metal-installer/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:{{VERSION}} \
      -n {{NODE}}

goatchat-register:
    bws run 'curl -v -H '\"'Authorization: SharedSecret $GOATCHAT_REGISTRATION_ADMIN_API_SHARE_SECRET'\"' \
        -H "Content-Type: application/json" \
        -d '\''{"max_usage": 0, "expiration_date": "2026-01-01"}'\'' \
        https://goatchat.ca/gate/api/token'
goatchat-register-review:
    bws run 'curl -v -H '\"'Authorization: SharedSecret $GOATCHAT_REGISTRATION_ADMIN_API_SHARE_SECRET'\"' \
        -H "Content-Type: application/json" \
        https://goatchat.ca/gate/api/token' | jq

refresh-client-cert:
    #!/bin/bash
    yq -r .machine.ca.crt controlplane.yaml | base64 -d > ca.crt
    yq -r .machine.ca.key controlplane.yaml | base64 -d > ca.key
    talosctl gen key --name admin           
    talosctl gen csr --key admin.key --ip 127.0.0.1 
    talosctl gen crt --ca ca --csr admin.csr --name admin --hours  8760
    yq -i '.contexts.fog.ca = "'"$(base64 -w0 ca.crt)"\
    '" | .contexts.fog.crt = "'"$(base64 -w0 admin.crt)"\
    '" | .contexts.fog.key = "'"$(base64 -w0 admin.key)"'"' \
    .config/talosconfig

    talosctl kubeconfig .config/kubeconfig -n 192.168.1.43
