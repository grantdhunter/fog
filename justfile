update:
    bws run 'helmfile deps'

deploy:
    bws run 'helmfile apply'

sdiff:
    bws run 'helmfile diff --output simple'

ddiff:
    bws run 'helmfile diff --output dyff'

cleanuppods:
    kubectl get pods --no-headers | grep -v Running  | awk '{print $1}' | xargs kubectl delete pod
    
