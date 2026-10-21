# keycloak-operator

Installs the [Keycloak Operator](https://www.keycloak.org/operator/installation)
cluster-wide: the Operator itself runs in its own `keycloak-operator` namespace, but
watches `Keycloak`/`KeycloakRealmImport` custom resources in **every** namespace. This is
required (not optional) for this project's setup: `.helm/ecamp3` deploys every PR
preview's Keycloak resources into the same shared app namespace as everything else, not a
dedicated one, and the Operator's plain/default install only watches its own installation
namespace — see the comment in `kustomization.yaml` for the exact tradeoff and links.

Unlike `.ops/api-gateway-traefik`, this is Kustomize-based, not Helm: the Keycloak project
does not publish an official Helm chart for the Operator itself (only Kustomize bases and
an OLM bundle for OpenShift-style clusters).

## Prerequisites

`kubectl` with cluster-admin-equivalent permissions (this installs `ClusterRole`s /
`ClusterRoleBinding`s and CRDs, which are cluster-scoped resources).

## Deployment

To diff the current deployment:

```shell
./deploy.sh diff
```

To deploy:

```shell
./deploy.sh deploy
```

## What gets installed

Verified locally via `kubectl kustomize .` (this only resolves the remote Kustomize
reference and renders it — it does not need cluster access, so this was checked without
ever touching a real cluster):

- CRDs: `keycloaks.k8s.keycloak.org`, `keycloakrealmimports.k8s.keycloak.org`,
  `keycloakoidcclients.k8s.keycloak.org`, `keycloaksamlclients.k8s.keycloak.org` — the
  first two are what `.helm/ecamp3/templates/keycloak.yaml` and
  `keycloak_realmimport.yaml` depend on.
- 1 Operator `Deployment` + `Service` + `ServiceAccount` in the `keycloak-operator`
  namespace, plus the `ClusterRole`/`ClusterRoleBinding`s needed for it to watch every
  namespace.

## Version note

Pinned to `26.7.3` in `kustomization.yaml`, not `26.0.8` (the version
`dev-setup/keycloak/Dockerfile` uses for the actual managed Keycloak instances) — the
`cluster-wide` Kustomize variant this depends on doesn't exist yet at the `26.0.8` tag
(confirmed: it 404s). The Operator is designed to manage a range of Keycloak server
versions, so running a newer Operator against 26.0.8-based instances is expected to work,
but that specific compatibility claim has not been verified against a live cluster.
