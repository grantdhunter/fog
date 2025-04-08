update:
    bws run 'helmfile deps'

deploy ARGS='--output simple -i':
    bws run 'helmfile apply {{ARGS}}'

sdiff ARGS='':
    bws run 'helmfile diff --output simple'

ddiff ARGS='':
    bws run 'helmfile diff --output dyff'

cleanuppods:
    kubectl get pods --no-headers | grep -v Running  | awk '{print $1}' | xargs kubectl delete pod
    
