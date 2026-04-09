# demo

Helm chart generated from K8s Studio diagram.

## Install

```bash
helm install demo ./demo
```

## Resources

- **Ingress** `app-ingress`
- **Service** `web-svc`
- **WebFrontend** `web`
- **Service** `api-svc`
- **APIServer** `api`
- **ConfigMap** `api-config`
- **Secret** `api-secrets`
- **Service** `db-svc`
- **Database** `postgres`
- **PersistentVolumeClaim** `postgres-pvc`
