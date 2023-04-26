# Demo: Bank-Vaults secret injection

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

Based on [this](https://web.archive.org/web/20230426101859/https://banzaicloud.com/blog/inject-secrets-into-pods-vault-revisited/) blog post.

## Prerequisites

- Ability to setup a Kubernetes cluster (eg. using [KinD](https://kind.sigs.k8s.io/))
- kubectl
- kustomize
- [Helm](https://helm.sh/)
- [vault CLI](https://developer.hashicorp.com/vault/downloads)
- kubectl [view-secret plugin](https://github.com/elsesiy/kubectl-view-secret) _(optional)_

## Preparations

Set up a new Kubernetes cluster using the tools of your choice.

This guide uses [KinD](https://kind.sigs.k8s.io/):

```shell
kind create cluster
```

_The rest of the instructions assume your current context is set to your demo cluster._

Add the `banzaicloud-stable` repo to Helm:

```shell
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
```

Install the [Vault operator](https://bank-vaults.dev/docs/operator/):

```shell
helm upgrade --install --wait --namespace vault-system --create-namespace vault-operator banzaicloud-stable/vault-operator
```

Install the [mutating webhook](https://bank-vaults.dev/docs/mutating-webhook/):

```shell
helm upgrade --install --wait --namespace vault-system --create-namespace vault-secrets-webhook banzaicloud-stable/vault-secrets-webhook
```

Install a new Vault instance:

```shell
kustomize build deploy/vault | kubectl apply -f -

sleep 2
kubectl -n vault wait pods vault-0 --for condition=Ready --timeout=120s # wait for Vault to become ready
```

Set the Vault token from the Kubernetes secret:

```shell
export VAULT_TOKEN=$(kubectl -n vault get secrets vault-unseal-keys -o jsonpath={.data.vault-root} | base64 --decode)
```

Tell the CLI where Vault is listening _(optional: this should be the default)_:

```shell
export VAULT_ADDR=http://127.0.0.1:8200
```

Port forward to the Vault service:

```shell
kubectl -n vault port-forward service/vault 8200 1>/dev/null &
```

Check access to Vault:

```shell
vault kv get secret/accounts/aws
```

Alternatively, open the UI (and login with the root token):

```shell
open $VAULT_ADDR
```

## Demo

Deploy the demo application:

```shell
kustomize build deploy/demo | kubectl apply -f -

kubectl wait deploy http-echo --for condition=Available=true --timeout=60s # wait for the application to become ready
```

Port forward to the `http-echo` service:

```shell
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

Look at the Pod (and notice that no mutation happened):

```shell
kubectl get pods -o yaml
```

Look at the environment variable values:

```shell
curl http://127.0.0.1:8080/env 2>/dev/null | grep -e AWS -e MYSQL
```

Expected output:
```
MYSQL_PASSWORD=vault:secret/data/mysql#MYSQL_PASSWORD
AWS_SECRET_ACCESS_KEY=vault:secret/data/accounts/aws#AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID=vault:secret/data/accounts/aws#AWS_ACCESS_KEY_ID
```

Enable mutation to inject secret values:

```shell
kubectl patch deploy http-echo --type=json -p='[{"op":"remove","path":"/spec/template/metadata/annotations/vault.security.banzaicloud.io~1mutate"}]'

kubectl rollout status deploy http-echo --timeout=60s # wait for the rollout to finish
```

_(You have to restart the port forward at this point):_

```shell
kill %2
wait %2
kubectl port-forward service/http-echo 8080 1>/dev/null &
```

Look at the Pod (and notice a number of mutations: init container, volumes and mounts, entrypoint (command) changed):

```shell
kubectl get pods -o yaml
```

Look at the environment variable values again:

```shell
curl http://127.0.0.1:8080/env 2>/dev/null | grep -e AWS -e MYSQL
```

Expected output:
```
MYSQL_PASSWORD=3xtr3ms3cr3t
AWS_SECRET_ACCESS_KEY=s3cr3t
AWS_ACCESS_KEY_ID=secretId
```

# Cleanup

Kill background jobs:

```shell
kill %2 # demo app port-forward
kill %1 # vault port-forward
```

Tear down the Kubernetes cluster:

```shell
kind delete cluster
```
