namespace := env("NAMESPACE", "argo")
pg_release := env("PG_RELEASE", "postgres")
argo_release := env("ARGO_RELEASE", "argo-workflows")
etl_release := env("ETL_RELEASE", "nightly-etl")

# List available recipes
default:
    @just --list

# Add helm repos and build chart dependencies
setup:
    helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts 2>/dev/null || true
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update
    helm dependency build charts/postgres
    helm dependency build charts/argo-workflows

# Deploy all charts (postgres -> argo-workflows -> nightly-etl)
deploy: setup
    @echo "==> Installing/upgrading PostgreSQL"
    helm upgrade --install {{ pg_release }} charts/postgres \
      --namespace {{ namespace }} \
      --create-namespace \
      --wait --timeout 2m
    @echo "==> Installing/upgrading Argo Workflows"
    helm upgrade --install {{ argo_release }} charts/argo-workflows \
      --namespace {{ namespace }} \
      --set argo.controller.persistence.postgresql.host={{ pg_release }} \
      --wait --timeout 3m
    @echo "==> Installing/upgrading nightly-etl workflow"
    helm upgrade --install {{ etl_release }} charts/nightly-etl \
      --namespace {{ namespace }}

# Seed a CSV into the etl-data PVC and run the workflow
run filename="test.csv":
    @echo "==> Seeding {{ filename }} into etl-data PVC"
    kubectl run etl-seed --rm -i \
      --namespace {{ namespace }} \
      --image=busybox \
      --restart=Never \
      --overrides='{ \
        "spec": { \
          "containers": [{ \
            "name": "etl-seed", \
            "image": "busybox", \
            "command": ["sh", "-c", "cat > /data/{{ filename }}"], \
            "stdin": true, \
            "volumeMounts": [{"name": "etl-data", "mountPath": "/data"}] \
          }], \
          "volumes": [{ \
            "name": "etl-data", \
            "persistentVolumeClaim": {"claimName": "etl-data"} \
          }] \
        } \
      }' < assets/{{ filename }}
    @echo "==> Submitting workflow with filename={{ filename }}"
    argo submit \
      --namespace {{ namespace }} \
      --from cronwf/nightly-etl \
      -p "filename={{ filename }}" \
      --wait --log

# Show deployed resources
status:
    kubectl get statefulsets,pods,svc,cronworkflows -n {{ namespace }}

# Tail argo-workflows server logs
logs-server:
    kubectl logs -n {{ namespace }} -l app.kubernetes.io/name=argo-workflows-server -f

# Tail argo-workflows controller logs
logs-controller:
    kubectl logs -n {{ namespace }} -l app.kubernetes.io/name=argo-workflows-workflow-controller -f

# Uninstall everything
teardown:
    -helm uninstall {{ etl_release }} --namespace {{ namespace }}
    -helm uninstall {{ argo_release }} --namespace {{ namespace }}
    -helm uninstall {{ pg_release }} --namespace {{ namespace }}
    @echo "PVCs are retained. To fully clean up:"
    @echo "  kubectl delete pvc --all -n {{ namespace }}"
    @echo "  kubectl delete namespace {{ namespace }}"

# Render templates locally without installing (for debugging)
template chart:
    helm template {{ chart }} charts/{{ chart }}
