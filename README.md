# Fog
Like the cloud but local.

## Required tools
- talosctl (https://www.talos.dev/v1.9/talos-guides/install/talosctl/ )
- kubectl (https://kubernetes.io/docs/tasks/tools/#kubectl )
- helm (https://helm.sh/ )
- helmfile (https://helmfile.readthedocs.io/en/latest/ )
- bitwarded secrets CLI (https://bitwarden.com/help/secrets-manager-cli/ )

## Talos Cluster
### Hardware
- HP ProDesk 400 G3 (x3)
- Seagate Iron Wolf 2Tb (x2)
- Western Digital Red Pro 2Tb
- Sabrent HDD Docking Station (3x)
- Switch
- Ecoflow River 3 Plus
- Ecoflow River 3
- Router
- Modem

#### HP ProDesk check list
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
         --config-patch-control-plane @talos/cluster_patch.yaml \
         --config-patch-control-plane @talos/remove_node_label_patch.yaml
```
### Add node to talos cluster
```sh
talosctl apply-config [--insecure] -n <ips> controlplane.yaml
```
### Update context
```sh
talosctl config node 192.168.1.38 192.168.1.43 192.168.1.39
```

### Kubeconfig
```sh
talosctl kubeconfig --nodes 192.168.1.43
```

## Applications

#### metrics
```sh
kubectl apply -f https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Apply and upgrade
check for updates:
```sh
bws run 'helmfile deps'
```
apply changes:
```sh
bws run 'helmfile apply'
```
### Extras
#### Ceph
```sh
kubectl label namespace rook-ceph pod-security.kubernetes.io/enforce=privileged
```

#### Traefik
```sh
kubectl create secret generic digitalocean-api-key --from-literal=token=$DIGITAL_OCEAN_API_TOKEN
```

#### Postgres
copy secret over to goatchat namespace
```sh
kubectl get secrets -n datastore postgres-pguser-synapse -o json | jq 'del(.metadata.resourceVersion,.metadata.uid,.metadata.ownerReferences) | .metadata.creationTimestamp=null,.metadata.namespace="goatchat"' | kubectl apply -f -
```

#### synapse
```
kubectl create secret generic goatchatca-signingkey --from-literal=signing.key=$GOATCHAT_SYNAPSE_SIGNING_KEY
```

#### Ghost Blogs
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
kngot
Create db and user
```sh
CREATE DATABASE kgnot_ghost;
grant all privileges on kgnot_ghost.* to kgnot_ghost@'10.%.%.%' identified by '$KGNOT_MYSQL_PASSWORD';
```
Install app
```sh
kubectl create secret generic ghost-kgnot-user-secret --from-literal=ghost-password=$KGNOT_GHOST_USER_PASSWORD
kubectl create secret generic ghost-kgnot-db-secret --from-literal=mysql-password=$KGNOT_MYSQL_PASSWORD
kubectl create secret generic kgnot-smtp-password --from-literal=smtp-password=$KNGOT_SMTP_PASSWORD
```
53ll
Create db and user
```sh
CREATE DATABASE 53ll_ghost;
grant all privileges on 53ll_ghost.* to 53ll_ghost@'10.%.%.%' identified by '$GHOST_53LL_MYSQL_PASSWORD';
```
Install app
```sh
kubectl create secret generic ghost-53ll-user-secret --from-literal=ghost-password=$GHOST_53LL_USER_PASSWORD
kubectl create secret generic ghost-53ll-db-secret --from-literal=mysql-password=$GHOST_53LL_MYSQL_PASSWORD
kubectl create secret generic 53ll-smtp-password --from-literal=smtp-password=$GHOST_53LL_SMTP_PASSWORD
```
