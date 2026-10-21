# Helm infrastructure for ecamp3

Here you also have some scripts to deploy ecamp3 from your local machine.

## Prepare

First you need to have the following dependencies:

- yq
- kubectl (with a kubeconfig for the cluster you want to deploy to)
- helm
- helmfile
- docker (with a public repository to push images to)
- openssl

## Setup

If you don't have JWT Passphrase, public and private key yet, you have to run:

```shell
./generate-jwt-values.sh
```

This copies [env.example.yaml](ecamp3/env.example.yaml) to [env.yaml](ecamp3/env.yaml)
if not exists and sets the jwt values.

Then you have to set the values in [env.yaml](ecamp3/env.yaml which are not set to any value.
(e.g. POSTGRES_URL).

## Build images

```shell
./build-images.sh
```

## Deploy to cluster

To diff the deployment

```shell
./deploy-to-cluster.sh
```

To deploy

```shell
./deploy-to-cluster.sh deploy
```

## For convenience

If you did not build the images for a long time, you have the convenience script:

```shell
./build-and-deploy.sh
```

## Keycloak admin console

When `KEYCLOAK_ENABLED` is set for a deployment, the admin console is reachable at
`https://<domain>/keycloak/admin/`. The `admin` user's password is generated once by the
chart (see `ecamp3/templates/keycloak.yaml`) and kept stable across redeploys -- it's not
printed anywhere during deploy, so fetch it from the cluster:

```shell
kubectl get secret <release-name>-keycloak-admin -n default -o jsonpath='{.data.password}' | base64 -d
```

e.g. for a deployment named `simfeld`, the release/secret is `ecamp3-simfeld-keycloak-admin`.
