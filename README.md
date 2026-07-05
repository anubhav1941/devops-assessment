[![Terraform CI](https://github.com/anubhav1941/devops-assessment/actions/workflows/terraform.yml/badge.svg)](https://github.com/anubhav1941/devops-assessment/actions/workflows/terraform.yml)

# DevOps Assessment - Terraform + Database Reliability

## Stack

Terraform, AWS, Docker Compose, PostgreSQL, GitHub Actions, Shell scripting

## Repo structure

```
infra/
  modules/
    network/   VPC, subnets, IGW, NAT gateway(s), route tables
    ecs/       ALB, ALB security group, ECS cluster/task/service, ECS security group
    rds/       RDS instance, RDS security group, subnet group
  envs/
    dev/       calls the 3 modules with dev sizing
    prod/      calls the 3 modules with prod sizing
db/
  docker-compose.yml
  migrations/
    001_create_tables.sql
    002_add_bookings_index.sql
  seed/
    seed.sql
  docker-entrypoint-initdb.d/
    01-init.sh   runs migrations then seed on first container start
scripts/
  backup.sh
  restore.sh
.github/workflows/terraform.yml
```

## Part 1 and 2 - Terraform

Network -> ALB -> ECS/Fargate -> RDS. RDS has no public access, only the ECS security group can reach it on 5432. ECS only accepts traffic from the ALB security group. ALB is the only thing open to the internet.

dev and prod are separate root modules under `infra/envs/`, each calling the same 3 modules with different variables:

| | dev | prod |
|---|---|---|
| AZs | 2 | 3 |
| NAT gateways | 1 shared | 1 per AZ |
| RDS instance | db.t4g.micro | db.r6g.large |
| RDS multi-AZ | no | yes |
| Backup retention | 1 day | 30 days |
| Deletion protection | off | on |
| ECS desired count | 1 | 3 |

To run:

```
cd infra/envs/dev
terraform fmt -recursive
terraform init
export TF_VAR_db_password="something"
terraform validate
terraform plan -refresh=false
```

Same for `infra/envs/prod`. No `apply` needed, actual deployment isn't required for this assessment. Confirmed working plan output: dev = 28 resources to add, prod = 38 (prod has more because of the extra AZ and per-AZ NAT gateways).

State is local (`backend.tf`) so this runs without needing an S3 bucket. In a real setup this would be an S3 backend with a DynamoDB lock table, commented example is in each `backend.tf`.

## Part 3 - GitHub Actions

`.github/workflows/terraform.yml` runs on every PR that touches `infra/**`. It runs fmt check, init, validate and plan for dev and prod in parallel, then posts the result as a PR comment and also uploads the plan output as a workflow artifact.

Needs 3 repo secrets to actually reach AWS during plan: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `TF_VAR_DB_PASSWORD`. Without these, fmt/init/validate still pass, plan just fails at the auth step (plan step has continue-on-error so it doesn't block the pipeline, since actual AWS access isn't required by the assignment).

Tested this on a real PR against my own repo, both `Terraform (dev)` and `Terraform (prod)` jobs passed.

## Part 4 - Local database

```
cd db
docker compose up -d
docker compose logs -f postgres
```

`01-init.sh` is the only file that sits directly in `docker-entrypoint-initdb.d/`, it runs the migration files and then the seed file in order. Postgres only auto-runs files that sit directly in that folder, not subfolders, so migrations and seed live in their own folders and get picked up by this script instead of being mounted straight into docker-entrypoint-initdb.d.

## Part 5 - Seed data and index

Seed script creates 5000 bookings spread across 6 cities, 8 orgs and 5 statuses, with events for about half the bookings. Needed more than one city/org/status or the query in the assignment doesn't have anything to filter/group on.

Query to optimize:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Before adding an index this does a seq scan over all 5000 rows to find the ~850 matching Delhi rows. Added:

```sql
CREATE INDEX idx_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

city is the equality filter and created_at is the range filter so city goes first in the index, then created_at. org_id, status and amount are added as INCLUDE columns, not part of the index key, just so the index can answer the whole query without going back to the table. That turns it into an index-only scan.

Actual EXPLAIN ANALYZE before the index:

```
Seq Scan on hotel_bookings  (cost=0.00..89.28 rows=1 width=150) (actual time=0.015..1.041 rows=299 loops=1)
  Filter: ((city = 'delhi') AND (created_at >= (now() - '30 days'::interval)))
  Rows Removed by Filter: 4701
Execution Time: 1.336 ms
```

After the index (and after running VACUUM ANALYZE, which updates the visibility map so Postgres can skip going back to the table):

```
Index Only Scan using idx_bookings_city_created_at on hotel_bookings (cost=0.29..22.17 rows=294 width=33) (actual time=0.667..1.627 rows=300 loops=1)
  Index Cond: ((city = 'delhi') AND (created_at >= (now() - '30 days'::interval)))
  Heap Fetches: 0
Execution Time: 1.917 ms
```

Heap Fetches: 0 is the part that matters, Postgres answered the query entirely from the index without touching the table. On 5000 rows the timing difference is small, on a real production table this would be a much bigger gap.

Note: right after a bulk seed, run `VACUUM ANALYZE hotel_bookings;` before checking the plan, otherwise the index is still used but with some heap fetches until the visibility map catches up.

## Part 6 - Backup and restore

```
cd scripts
./backup.sh
```

Creates a timestamped dump in `../backups/`.

```
./restore.sh ../backups/appdb_backup_<timestamp>.sql
```

Restores into a separate database called `appdb_restore_test`, never touches the real `appdb`.

To verify the restore actually worked, don't just check row counts, compare a checksum of the actual data:

```
docker exec -it hotel_bookings_db psql -U appadmin -d appdb -t -c "SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM hotel_bookings;"
docker exec -it hotel_bookings_db psql -U appadmin -d appdb_restore_test -t -c "SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM hotel_bookings;"
```

Both hashes should be identical. Tested this, got `a9526d087a02542be67c6860c7f2d53b` on both sides.

## How to run everything end to end

```
cd infra/envs/dev && terraform fmt -recursive && terraform init && terraform validate && terraform plan -refresh=false
cd ../prod && terraform fmt -recursive && terraform init && terraform validate && terraform plan -refresh=false
cd ../../../db && docker compose up -d
cd ../scripts && ./backup.sh
./restore.sh ../backups/<the file backup.sh just created>
```
