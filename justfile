update:
    bws run 'helmfile deps'

deploy ARGS='--output simple -i':
    bws run 'helmfile apply {{ARGS}}'

sdiff ARGS='':
    bws run 'helmfile diff --output simple'

ddiff ARGS='':
    bws run 'helmfile diff --output dyff {{ARGS}}'

cleanuppods:
    kubectl get pods --no-headers | grep -v Running  | awk '{print $1}' | xargs kubectl delete pod
    
pgrestart:
    kubectl patch postgrescluster/postgres  --type merge --patch '{"spec":{"metadata":{"annotations":{"restarted":"'"$(date)"'"}}}}'