# argo-workflows-demo

Demo of Argo Workflows with PostgreSQL persistence, deployed as independent Helm charts.

## Architecture

```
charts/
  postgres/        # PostgreSQL via bjw-s app-template (StatefulSet)
  argo-workflows/  # Argo Workflows engine (upstream chart wrapper)
  nightly-etl/     # Example CronWorkflow that processes a CSV
```

- **postgres** — `postgres:18.2-trixie` deployed as a StatefulSet with an init script that creates the `workflows` database and role
- **argo-workflows** — Wraps the upstream `argo-workflows` chart (v0.47.3) with PostgreSQL persistence for workflow archiving
- **nightly-etl** — A CronWorkflow that mounts a PVC, reads a CSV, and runs a .NET console app. Runs nightly at 2am ET

## Prerequisites

- Kubernetes cluster
- [Helm](https://helm.sh/docs/intro/install/)
- [Argo CLI](https://argo-workflows.readthedocs.io/en/latest/walk-through/argo-cli/)
- [just](https://github.com/casey/just#installation)

## Quick Start

```bash
just deploy       # stands up all three charts
just run          # seeds test.csv into PVC + triggers the workflow
just status       # show pods, services, cronworkflows
```

## Recipes

```
just              # list all recipes
just deploy       # deploy all charts
just run          # run workflow with assets/test.csv
just run foo.csv  # run workflow with a specific file
just status       # show deployed resources
just logs-server  # tail argo server logs
just logs-controller  # tail argo controller logs
just teardown     # uninstall everything
just template postgres      # render chart templates locally
just template argo-workflows
just template nightly-etl
```

## Configuration

Override namespace or release names via environment variables:

```bash
NAMESPACE=workflows just deploy
PG_RELEASE=pg just deploy
```

Chart values can be customized by editing `charts/<name>/values.yaml` or via `--set` flags added to the justfile recipes.
