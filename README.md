# Fog 
Like the cloud but local.

## Required tools 
- talosctl (https://www.talos.dev/v1.9/talos-guides/install/talosctl/ )
- kubectl (https://kubernetes.io/docs/tasks/tools/#kubectl )
- bitwarded secrets CLI (https://bitwarden.com/help/secrets-manager-cli/ )

## Talos Cluster
### Machine check list
Using refurbished hardware is an adventure in configuration, make sure some things are standard before starting.
- Secure boot is off 
- BIOS password disabled
- Enable restore after power outage
### Generate config 
```sh
bws secret get <talos-secret-id> -o json | jq .value --raw-output > talos/secrets.yaml
talosctl gen config fog  https://192.168.1.43:6443 \
         --with-secrets talos/secrets.yaml \
         --config-patch @talos/machine_patch.yaml \
         --config-patch @talos/cluster_patch.yaml 
```
### Add node to talos cluster
```sh
talosctl apply-config [--insecure] -n 192.168.1.38 --file talos/worker.yaml 
talosctl apply-config [--insecure] -n 192.168.1.39 --file talos/worker.yaml 
talosctl apply-config [--insecure] -n 192.168.1.43 --file talos/controlplane.yaml 
```
### Update context
```sh 
talosctl config node 192.168.1.38 192.168.1.43 192.168.1.39
```

### Kubeconfig
```sh
talosctl kubeconfig --nodes 192.168.1.43
```
### metrics
```sh
kubectl apply -f https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

```
### Ceph 
```sh
helm repo add rook-release https://charts.rook.io/release
helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph
kubectl label namespace rook-ceph pod-security.kubernetes.io/enforce=privileged
helm install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster -f rook-ceph-cluster/values.yaml

```

### Metallb
```sh
helm repo add metallb https://metallb.github.io/metallb
helm install --create-namespace --namespace metallb-system metallb metallb/metallb
kubectl label namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/warn=privileged
kubectl -n metallb-system apply  -f metallb/ipaddresspool.yaml 

```

### Traefik
```sh
helm repo add traefik https://traefik.github.io/charts
kubectl create secret generic digitalocean-api-key --from-literal=token=$DIGITAL_OCEAN_API_TOKEN
helm install --create-namespace --namespace traefik traefik traefik/traefik\
             --values traefik/values.yaml \
             --set certificatesResolvers.letsencrypt.acme.email=$ACME_EMAIL \
             --set 'extraObjects[0].stringData.password'=$TRAEFIK_ADMIN_PASSWORD

```

### Postgres
```sh 
helm install pgo --create-namespace --namespace postgres-operator ../postgres-operator/helm/install --values postgres/operator-values.yaml
helm install postgres --create-namespace --namespace datastore ../postgres-operator/helm/postgres --values postgres/values.yaml

# copy secret over to goatchat namespace 
kubectl get secrets -n datastore postgres-pguser-synapse -o json | jq 'del(.metadata.resourceVersion,.metadata.uid,.metadata.ownerReferences) | .metadata.creationTimestamp=null,.metadata.namespace="goatchat"' | kubectl apply -f -
```

### Mariadb
```sh
helm install --create-namespace --namespace datastore mariadb  oci://registry-1.docker.io/bitnamicharts/mariadb --values mariadb/values.yaml
```

## Goatchat (matrix)
### Synapse
#### Setup db
delete synapse db and recreate with correct locale 
```sh 
PRIMARY_POD=$(kubectl -n datastore get pods --selector='postgres-operator.crunchydata.com/cluster=postgres,postgres-operator.crunchydata.com/role=master' -o jsonpath='{.items[*].metadata.labels.statefulset\.kubernetes\.io/pod-name}') 
PGPASSWORD=$(kubectl -n datastore get secrets  "postgres-pguser-grant" -o go-template='{{.data.password | base64decode}}')

kubectl -n datastore exec -it "$PRIMARY_POD" -- psql -c 'DROP DATABASE synapse;'
kubectl -n datastore exec -it "$PRIMARY_POD" -- createdb --encoding=UTF8 --locale=C --template=template0 --owner=synapse synapse
```
backup/restore db
```sh
kubectl -n datastore exec -it $PRIMARY_POD --  pg_dump -Upostgres -Fc --exclude-table-data e2e_one_time_keys_json synapse > synapse.dump

kubectl port-forward $PRIMARY_POD 5432:5432
PGSSLMODE=disable  pg_restore -h localhost -U synapse -vv -d synapse < synapse.dump

```
#### Install Synapse
```sh 
helm repo add ananace-charts https://ananace.gitlab.io/charts

kubectl create ns goatchat
kubectl create secret generic goatchatca-signingkey --from-literal=signing.key=$GOATCHAT_SYNAPSE_SIGNING_KEY
helm upgrade --create-namespace \
             --namespace goatchat \
             goatchat ananace-charts/matrix-synapse \
             --set config.macaroonSecretKey=$GOATCHAT_SYNAPSE_MACAROON_SECRET_KEY \
             --set config.registrationSharedSecret=$GOATCHAT_REGISTRATION_SHARED_SECRET \
             --set extraConfig.email.smtp_pass=$GOATCHAT_SMTP_PASSWORD \
             --values synapse/values.yaml \
             --install
```

### Install Matrix Registration
TODO: make this a helm app or replace with something better
```sh
kubeclt apply -k matrix-registration

```
## Ghost Blogs
### kngot
I got tired of fighting the docker container so I manually overrode the `config.production.json`
which looks like 
```
{
  "url": <url>,
  "server": {
    "port": 2368,
    "host": "::"
  },
  "mail": {
    "transport": "SMTP",
      "options": {
          "host": "smtp.sendgrid.net",
          "service": "SendGrid",
          "port": 465,
          "secure": true,
          "tls": {
              "requireTLS": true
          }
      }
  },
  "logging": {
    "transports": [
      "file",
      "stdout"
    ]
  },
  "process": "local",
  "paths": {
    "contentPath": "/opt/bitnami/ghost/content"
  },
  "database": {
    "client": "mysql",
    "connection": {
      "host": "mariadb.datastore.svc.cluster.local",
      "port": 3306,
      "user": <user>,
      "password": <password>,
      "database": <database>
    }
  }
}
```

#### Create db and user
```sh
CREATE DATABASE kgnot_ghost;
grant all privileges on kgnot_ghost.* to kgnot_ghost@'10.%.%.%' identified by '$KGNOT_MYSQL_PASSWORD';
```
#### Install app 
```sh 
kubectl create secret generic ghost-kgnot-user-secret --from-literal=ghost-password=$KGNOT_GHOST_USER_PASSWORD
kubectl create secret generic ghost-kgnot-db-secret --from-literal=mysql-password=$KGNOT_MYSQL_PASSWORD
kubectl create secret generic kgnot-smtp-password --from-literal=smtp-password=$KNGOT_SMTP_PASSWORD
helm install --create-namespace \
             --namespace ghost \
             kgnot-ghost oci://registry-1.docker.io/bitnamicharts/ghost \
             --set ghostUsername=$KGNOT_GHOST_USER_NAME \
             --values kgnot/values.yaml
```

### 53ll
#### Create db and user
```sh
CREATE DATABASE 53ll_ghost;
grant all privileges on 53ll_ghost.* to 53ll_ghost@'10.%.%.%' identified by '$GHOST_53LL_MYSQL_PASSWORD';
```
#### Install app 
```sh 
kubectl create secret generic ghost-53ll-user-secret --from-literal=ghost-password=$GHOST_53LL_USER_PASSWORD
kubectl create secret generic ghost-53ll-db-secret --from-literal=mysql-password=$GHOST_53LL_MYSQL_PASSWORD
kubectl create secret generic 53ll-smtp-password --from-literal=smtp-password=$GHOST_53LL_SMTP_PASSWORD
helm install --create-namespace \
             --namespace ghost \
             53ll-ghost oci://registry-1.docker.io/bitnamicharts/ghost \
             --set ghostUsername=$GHOST_53LL_USER_NAME \
             --values 53ll/values.yaml
```

