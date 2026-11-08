# Week of 2026-11-09 → 2026-11-13

Ship the billing export, close the on-call follow-ups, and move the docs
site. ~~Rewrite the CLI~~ moved to next week.

## Goal 1 — Billing CSV export

- [x] Agree on the columns with finance
- [x] Add the `export_invoices` job
- [x] Stream rows instead of building the file in memory
- [ ] Review: [PR #482](https://example.com/pr/482)
- [ ] Ship behind the `billing_export` flag
  - [ ] Turn it on for the beta accounts

### Waiting on others

- [ ] Finance signs off the sample file

## Goal 2 — On-call follow-ups

- [x] Alert on queue depth, not on worker restarts
- [ ] Runbook for the *disk full* page
- [ ] Remove the noisy staging pings

## Goal 3 — Docs site

| Page | State |
|---|---|
| Getting started | done |
| API reference | in review |

- [ ] Redirects for the old URLs
- [ ] Announce it in **#engineering**

> Friday: demo the export, then the retro.
