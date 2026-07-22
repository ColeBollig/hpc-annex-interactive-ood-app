# HTC Annex OOD App — TODO

## In Progress / Next Up

- [ ] Get Ian to handle the user-facing documentation and onboarding
- [ ] Demo to Miron
- [ ] Share interactive app with users
- [ ] Move repo into HTCondor project space

## Open Questions

- [ ] `~/.condor/annex_slurm_args` has no effect with the OOD interactive app setup — the OOD form controls all `#SBATCH` options. Decide if this needs a workaround or if the form fields are sufficient.
- [ ] Explore how user-specified resource inputs (CPUs, memory, wall time) propagate to pilot job advertisements visible in HTCondor — confirm EPs advertise what the form requested.

## Completed

- [x] Make annex source tarball the first form field
- [x] Define defaults, min, max, step for all numeric fields
- [x] Apply all form inputs to `submit.yml.erb` (CPUs, memory, GPUs, wall time, account, email)
- [x] Make partition selection dynamic via `auto_queues` (no hardcoded partition list)
- [x] Make cluster selection dynamic via `cluster: "*"` (works on any OOD-configured Slurm system)
- [x] Collapse `email_on_started`/`email_on_ended` into a single `send_email` checkbox (sends `--mail-type=BEGIN,END`), hide `user_email` until it's checked, and hide the whole email section unless `scontrol show config` reports a configured `MailProg` — plus an admin override (`HTC_ANNEX_EMAIL_ENABLED` in the app's `env` file, see README.md) for when a configured `MailProg` doesn't mean mail actually works (our case — see the mail relay note above)
- [x] Let admins override default `num_cores`/`memory_gb`/`num_gpus` per-install via `HTC_ANNEX_DEFAULT_*` env vars (see README.md), falling back to the built-in defaults (1 core, 4GB, 0 GPUs) and clamping to each field's min/max
- [x] Fix `submit.yml.erb`'s blank-field fallback for `num_cores`/`memory_gb` to reuse the same `HTC_ANNEX_DEFAULT_*` resolution instead of stale hardcoded `1`/`4` literals, so a cleared field doesn't silently ignore the admin's configured default
- [x] Full bug/consistency sweep: quoted the unquoted `$SOURCE` path in `template/before.sh.erb` (broke on filenames with spaces), added a `timeout` to the `scontrol` autodetect, closed a YAML-injection gap by validating `bc_account`/`user_email` against strict regexes before interpolating them, and made `send_email`/`user_email` always present in form context (as `hidden_field` when unsupported) instead of relying on `defined?` against OOD's context internals
- [x] Let admins override `min`/`max` (not just the default) per resource via `HTC_ANNEX_MIN_*`/`HTC_ANNEX_MAX_*`, applied directly to the form fields' allowed range; validate the resolved `{min, max, default}` triple as a unit (see README.md); extracted all of this into `lib/annex_defaults.rb`, required by both `form.yml.erb` and `submit.yml.erb`, eliminating the duplicated helper
- [x] Test full loop: place job on AP, create annex, move tarball to HPC, launch via OOD, confirm job exits cleanly - Tested via personal LVM VM host w/ minicondor to Spark via OOD
- [x] Package app into a git repo
- [x] Corrected a wrong path in README.md's Admin Configuration section: interactive apps share the Dashboard's env file (`/etc/ood/config/apps/dashboard/env`), not a per-app-token one — verified against OOD's `customizations.html` docs and a maintainer's discourse reply, since the per-app-token pattern only applies to standalone apps like Shell/Job Composer
- [x] Add `info.html.erb` session-card warning (idle-shutdown timeout) + detected HTCondor version, read from `annex.record` inside the user's tarball via new `lib/annex_record.rb` (see README.md's Session Card Info section). Verified against a real annex tarball's actual files (`annex.record`, `annex-setup.sh`, `annex-node.sh`) rather than guessing at HTCondor annex tooling internals; confirmed `annex-node.sh` never modifies `STARTD_NOCLAIM_SHUTDOWN`/`VERSION` after they're applied to the pilot's config. Relies on an undocumented-but-confirmed-working `staged_root` variable in `submit.yml.erb`/`info.html.erb` — not part of OOD's official API for these two files, so both are wrapped in `rescue` and degrade to just not showing this section if a future OOD version breaks it
- [x] Fix a real accuracy gap in the above: `annex-setup.sh` sources the user's own `~/.condor/annex_config` *after* the tarball's `annex.record` but *before* using `VERSION`/`STARTD_NOCLAIM_SHUTDOWN` — a user override there (a supported customization point per USER-STEPS.md) would silently make our plain tarball read stale. Added `AnnexRecord.effective`, which simulates that exact precedence (source the record, then the user's own `annex_config`, same as `annex-setup.sh`) at submit time; `submit.yml.erb` now calls this instead of the plain `read`. Corrected the now-wrong "no accuracy difference" claim this same entry used to make
- [x] Figure out annex time issues - STARTD_NOCLAIM_SHUTDOWN causes pilot to exit early (default 5 min): Now add warning to information page
- [x] Corrected two more README.md inaccuracies found via a live OOD 4.0.3 test: (1) there is no per-app `.env`/`env` file for a dev sandbox copy of this app — that only exists for standalone engines like Job Composer; a batch-connect app's `ENV` always comes from `/etc/ood/config/apps/dashboard/env`, dev or sys, verified against OOD's source at the v4.0.3 tag (`BatchConnect::App#render_erb_file`, `ConfigurationSingleton#load_dotenv_files`); (2) documented that `user_email`'s hide-until-checked behavior does nothing unless the instance-wide `bc_dynamic_js` flag is enabled (`/etc/ood/config/ondemand.d/*.yml`) — confirmed this gates `makeChangeHandlers()`/`dynamic_forms.js` and was missing from our docs entirely
- [x] Set email override (`HTC_ANNEX_EMAIL_ENABLED=false`) on OOD Spark App — confirmed working. Root cause of the initial "not working" report: `/etc/ood/config/` was visible on `spark-login` via a shared/NFS path, but the actual Dashboard/PUN process runs on the separate OOD web server host — editing/restarting on `spark-login` had no effect since nothing OOD-related actually runs there. Documented this gotcha in README.md's Admin Configuration section
