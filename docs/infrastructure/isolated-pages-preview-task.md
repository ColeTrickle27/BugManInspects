# Task: Isolated Cloudflare Pages preview environment

## Purpose

Establish a non-production Cloudflare Pages preview environment that can be used
for destructive integration testing, including SalesBrain Quote Workspace write
paths. This task is an infrastructure prerequisite, not authorization to run
those integration tests.

**Gate:** SalesBrain write tests must remain blocked until every acceptance check
below has recorded evidence and the infrastructure owner marks this task passed.

## Scope

Create dedicated preview resources in the OpsBrain-owned Cloudflare account:

- a preview-only D1 database;
- a preview-only R2 bucket;
- preview-only authentication/session configuration; and
- synthetic customers, locations, quotes, graph records, and files with an
  unmistakable `PREVIEW-TEST-` identifier prefix.

Configure only the **Preview** environment of the Pages project. Keep the
Production environment and all production resources unchanged.

## Required isolation controls

1. Use new resource IDs and names. A preview D1 database ID or R2 bucket name
   must never equal any production binding target.
2. Bind the preview deployment directly to those preview resources. Do not use
   production bindings as fallbacks.
3. Use a preview-only session signing secret, cookie name, and cookie domain.
   The preview cookie domain must be the exact preview hostname (or host-only),
   never a production parent domain.
4. Give the preview environment a distinct auth issuer/audience and callback
   allowlist containing only approved preview URLs. Production callbacks must
   not be added or changed.
5. Use least-privilege preview credentials. They may access only the preview D1
   database and preview R2 bucket. Do not copy production tokens or secrets.
6. Seed synthetic records only. Never clone customer, quote, graph, attachment,
   session, or other business data from production.
7. Add an explicit environment marker such as `APP_ENV=preview` and fail closed
   during startup if a preview deployment is given a production resource ID,
   bucket, auth issuer, cookie domain, or API origin.

Secret values, tokens, session material, and production identifiers must not be
committed to this repository or pasted into task evidence.

## Synthetic fixture minimum

Create uniquely prefixed, non-routable data sufficient for the later workflow:

- one Bill-To and one Location;
- one SalesBrain quote/workspace record;
- one BugMan graph record;
- one small R2 attachment; and
- one preview user/session identity with only the permissions needed by the
  integration test.

Use reserved/example contact data (for example, `example.invalid`) and no real
customer names, addresses, phone numbers, email addresses, graph files, or
attachments.

## Verification procedure

An infrastructure owner with Cloudflare access must capture redacted command
output or dashboard screenshots for each check. Evidence must show resource
names and stable fingerprints sufficient to compare bindings, but must redact
secrets, tokens, full production IDs, and customer data.

### 1. Binding separation (no writes)

Export the Pages Preview and Production binding inventories through the
Cloudflare API or Wrangler. Compare the target fingerprints and prove:

- preview D1 ID is different from the production D1 ID;
- preview R2 bucket is different from the production R2 bucket;
- preview auth issuer/audience, cookie name/domain, and session-secret version
  are different from production; and
- the preview service credential policy names only preview resources.

A name-only environment label is not proof; compare actual binding targets.

### 2. D1 write isolation

1. Record the absence of a fresh random canary key in both environments.
2. Through the deployed preview API, write a synthetic row using that key.
3. Read it back through the preview API.
4. Query production **read-only** for the exact canary key and prove it remains
   absent.
5. Delete the canary from preview and prove it remains absent from production.

Do not issue any insert, update, delete, migration, or schema command against
production while performing this proof.

### 3. R2 write isolation

Repeat the canary procedure with a randomly named, harmless text object:

1. prove the key is initially absent from both buckets;
2. upload it through the deployed preview API;
3. read it back from preview;
4. prove via a production **read-only** lookup that the key is absent; and
5. delete it from preview.

### 4. Session isolation

1. Authenticate only against preview with the synthetic preview user.
2. Prove the issued cookie has the preview-only name/domain and secure
   attributes.
3. Present that preview session to a harmless production identity/read endpoint
   and prove production rejects it (`401` or `403`).
4. Prove a production session is not accepted by preview, without performing a
   write.
5. Confirm logout/revocation affects only the preview session store.

Never include cookie values or authorization headers in retained evidence.

### 5. Synthetic-data check

Query the preview resources and show that all task-created rows and objects use
`PREVIEW-TEST-` identifiers. Run read-only checks proving those exact identifiers
are absent from production. Review the fixtures to confirm they contain no real
customer or employee data.

## Pass criteria

The task passes only when all of the following are true:

- all four preview concerns (D1, R2, auth/session, synthetic data) are present;
- binding inventories prove distinct preview and production targets;
- preview D1 and R2 canaries are readable in preview and absent in production;
- preview and production sessions are mutually rejected;
- production was accessed read-only solely for the isolation assertions;
- Cloudflare audit logs show no production mutation from the setup/test actor;
- canaries have been removed from preview;
- evidence has been reviewed by the infrastructure owner; and
- the evidence record includes date, tester, preview URL, deployment ID, and
  redacted resource fingerprints.

Any ambiguous binding, unexpected production result, or inability to inspect
an audit trail is a failure. Stop testing, revoke the preview credential, and
investigate before retrying.

## Rollback

Rollback affects preview only: disable the preview deployment, revoke its
preview-scoped credentials and session secret, and delete the synthetic preview
resources after retaining approved audit evidence. Do not edit, rotate, delete,
or rebind any production resource as part of rollback.

## Explicitly not in scope

- application source or feature changes;
- SalesBrain integration writes or Quote Workspace testing;
- production resource, binding, secret, data, or session changes;
- copying production data into preview;
- merging branches;
- deploying application changes; or
- changing the existing production deployment workflow.
