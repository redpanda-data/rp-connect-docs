# Memory

## PR naming conventions
When referencing PRs titled "auto-docs: Update RPCN connector docs", always specify which connectors and version are involved. Example:
- PR #378 — auto-docs: Update RPCN connector docs (iceberg output, v4.81.0)
- PR #385 — auto-docs: Update RPCN connector docs (aws_cloudwatch_logs input, v4.81.0 improvements)

## DOC-1994 (Iceberg connector)
- PR #378 (merged) — initial auto-generated iceberg draft, v4.81.0, self-hosted only
- PR #385 (open) — improvements to iceberg page + aws_cloudwatch_logs content; CI passing, needs writer review (credentials prose, cgo formatting, metadata xref)
- cloud-docs PR #523 — aws_cloudwatch_logs input only (iceberg not in cloud)

## DOC-1919 (IAM roles for BYOC)
- Page at `modules/guides/pages/cloud/aws-iam-aurora.adoc`
- PR #388 open for review
- Source material: https://github.com/supahcraig/RPCN-to-Aurora-via-IAM/

## DOC-1771 (CDC cookbooks)
- PR #392 open — 6 cookbooks: mysql_cdc, postgres_cdc, mongodb_cdc, microsoft_sql_server_cdc, tigerbeetle_cdc, gcp_spanner_cdc
- Each cookbook: 1 adoc page + 5 YAML examples (basic-capture, filter-events, to-redpanda, to-s3, route-by-event)
- Pattern: capture → filter → route to Redpanda → route to S3 → route by event → replication/streaming mode → troubleshoot → next steps
- Gotcha: broken xrefs to non-existent cache pages (e.g. `caches/postgres.adoc`) silently suppress the page from the build. Use `caches/sql.adoc` instead.
- Gotcha: `broker: fan_out` with `processors` nested inside individual outputs (e.g. `kafka_franz`) fails lint. Use `switch` output with `check:` conditions instead.
- Gotcha: tigerbeetle_cdc requires cgo binary — add `SKIP_LINT=true` in `test-config.sh` to skip linting.
- Gotcha: Netlify deploy previews fail if the PR branch is behind main and missing pages that other repos (e.g. cloud-docs) include. Always merge main before pushing a PR.

## Netlify preview URLs
- Pattern: `https://deploy-preview-{PR}--redpanda-connect.netlify.app/redpanda-connect/{module}/{page-path}/`
- Antora preserves underscores in filenames — do NOT convert to hyphens in preview URLs
- Component reference pages (inputs, outputs, etc.) always use underscores (upstream naming)
- Authored pages (cookbooks, guides) should use hyphens per style guide, but existing cookbooks use underscores

## PRs (as of 2026-03-13)
- PR #378 — auto-docs (iceberg output, v4.81.0) — MERGED
- PR #383 — DOC-1923 XML namespace fix — MERGED
- PR #385 — auto-docs (aws_cloudwatch_logs + iceberg improvements, v4.81.0) — open, CI passing, needs writer review
- PR #381 — DOC-1978 metrics label field fix — open, 1 approval, awaiting second reviewer
- PR #382 — DOC-1917 ttlru broken link — open, awaiting reviewers
- PR #384 — DOC-1880 broker content fix — open, Netlify passing, awaiting review
- PR #389 — DOC-1806 sql_insert static fields + sql_raw dynamic ops — open
- PR #390 — DOC-1853 aws_s3 improvements — open
- PR #388 — DOC-1919 IAM roles for Aurora guide — open, awaiting docs team/david-yu/supahcraig
- PR #392 — DOC-1771 CDC cookbooks (6 connectors) — open, CI passing, awaiting review
- PR #386 — DOC-1909 Oracle CDC draft — open, awaiting Joe Woodward (due March 27)
- cloud-docs PR #523 — aws_cloudwatch_logs input page — open
- PR #377 — dependency update (bot) — open, no action needed

## Jira Cloud ID
- Cloud ID: `redpanda-data.atlassian.net`

## Auto-docs workflow
- Marking an item as complete in Aha triggers auto-generation of a docs PR
- DOC-1142 (Salesforce) — Joyce set it to complete in Aha to trigger the PR

## Style Review Workflow
- Run `docs-team-standards:review` on any page before submitting a PR
- Key rules: no "should/please/in order to/check out", active present tense, second person, commas after introductory clauses, field names in backticks, "real time" (two words)
- For auto-generated field descriptions, fix via `docs-data/overrides.json` using `$ref` — never edit partials directly

## Workflow Notes
- Always merge main before pushing to any open PR branch: `git merge origin/main --no-edit`
- Run `npm run build` before submitting PRs
- Build exits 0 in rp-connect-docs; one known error in cloud-docs: iceberg.adoc include missing (external, not our repo)
- cloud-docs lives at /tmp/cloud-docs
- cloud-docs PRs are thin wrappers using `include::...adoc[tag=single-source]`

## Key Paths
- Nav: `modules/ROOT/nav.adoc`
- Guides/cloud: `modules/guides/pages/cloud/`
- Configuration: `modules/configuration/pages/`
- Components outputs: `modules/components/pages/outputs/`
- Components processors: `modules/components/pages/processors/`

## Review heuristics (from David's feedback on PR #388)
- If a code block is referenced by filename in a CLI command (e.g. `file://trust-policy.json`), add a title to the block: `.trust-policy.json` immediately before `[source,json]`
- If a step shows what to create (e.g. a JSON policy), it should also show how to create it (e.g. the `aws iam` CLI commands)
- These apply to any step-by-step guide with config files and CLI workflows

## Patterns
- `sql_insert` table/columns are static strings — no Bloblang interpolation; use `sql_raw` for dynamic SQL
- `sql_raw` requires `unsafe_dynamic_query: true` for Bloblang interpolation in `query` field (SQL injection risk)
- broker.adoc: "simultaneously" removed — only applies to fan_out, not all patterns
- `aws.endpoint` required in postgres_cdc/mysql_cdc pipeline YAML for IAM auth
