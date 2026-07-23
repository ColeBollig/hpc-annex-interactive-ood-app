# HTC Annex — Open OnDemand Interactive App

An Open OnDemand batch-connect app that submits an HTCondor annex as a Slurm job. It lets users launch HTCondor execute points (EPs) on an HPC cluster directly from the OOD web interface, without manually writing or submitting a Slurm batch script.

## How It Works

The app is not a traditional interactive app — there is no web UI served after launch. Instead, OOD is used as a front-end to configure and submit a Slurm job that runs the annex pilot.

```
[HTCondor Access Point]
  htcondor annex create <NAME>
        │
        ▼
  annex-setup.tar   ──── scp ────►  [HPC home directory]
                                            │
                                     [OOD Form: annex/]
                                     cluster, partition,
                                     CPUs, memory, GPUs,
                                     wall time, account
                                            │
                                     Slurm job submitted
                                            │
                              ┌─────────────┴──────────────┐
                         before.sh.erb               script.sh
                         - Verify tarball           - bash hpc.slurm
                         - tar -xvf <tarball>             │
                         - bash annex-setup.sh       srun annex-node.sh
                              │                           │
                         Downloads HTCondor         HTCondor EP starts
                         Writes hpc.slurm           Connects to collector
                                                    Runs user jobs
```

`annex-setup.sh` (from the tarball) generates `hpc.slurm`, but because OOD runs it as `bash hpc.slurm` rather than submitting it via `sbatch`, the `#SBATCH` headers in that file are inert comments. All resource allocation is handled by OOD through `submit.yml.erb`.

`annex-node.sh` (from the tarball) reads Slurm environment variables (`SLURM_CPUS_ON_NODE`, `SLURM_MEM_PER_NODE`, `SLURM_JOB_END_TIME`) to configure what the HTCondor EP advertises to the pool.

## App Files

| File | Purpose |
|------|---------|
| `manifest.yml` | OOD app metadata (name, category, icon) |
| `form.yml.erb` | OOD form definition — resource controls shown to the user |
| `submit.yml.erb` | Maps form values to Slurm job parameters |
| `lib/annex_defaults.rb` | Shared admin-configuration resolution (resource min/max/default, email support), `require`d by both `form.yml.erb` and `submit.yml.erb` |
| `lib/annex_record.rb` | Reads `annex.record` out of the user's selected tarball without a full extract; `require`d by `submit.yml.erb` |
| `lib/annex_pilot_config.rb` | Resolves the pilot's effective `STARTD_NOCLAIM_SHUTDOWN` from static config fragments; copied into `staged_root` by `submit.yml.erb`, `load`ed back by `info.html.erb` (see [Session Card Info](#session-card-info)) |
| `info.html.erb` | Extra info shown on the session card (see [Session Card Info](#session-card-info)) |
| `template/before.sh.erb` | Pre-launch: validates and extracts the tarball, runs `annex-setup.sh` |
| `template/script.sh` | Main job body: runs `bash hpc.slurm` to launch EPs via `srun` |
| `logo.svg` | App icon shown in the OOD dashboard |

## Contents of annex-setup.tar

The tarball produced by `htcondor annex create` on the access point (see [USER-STEPS.md](USER-STEPS.md) Step 2) contains everything needed to start the annex on the HPC cluster:

| File | Purpose |
|------|---------|
| `annex.record` | Annex metadata: HTCondor version, job name, collector address, owner, request ID, schedd |
| `annex.token` | JWT token authorizing the EP to advertise to the HTCondor collector |
| `annex.password` | Shared secret for HTCondor pool security |
| `annex-setup.sh` | Downloads HTCondor binaries and writes `hpc.slurm` |
| `annex-job-setup.sh` | Extracts HTCondor binaries and configures the pilot directory |
| `annex-node.sh` | Runs on the Slurm node: reads Slurm env vars, configures the EP, starts `condor_master` |
| `00-annex-pilot-base` | Base HTCondor config for EPs (collector, security, shutdown policy, slot ads) |

## Admin Configuration

All settings below are read from `/etc/ood/config/apps/dashboard/env` (managed by the OOD admin, not part of this repo). Interactive apps like this one are all rendered by the single Dashboard Passenger process, so this file — not a per-app one — is where their environment variables live; it's shared across every interactive app on the instance, not exclusive to HTC Annex.

**This is also true for a personal dev/sandbox copy of this app** (`~/ondemand/dev/<name>/`) — there is no per-app `.env`/`env` file for a batch-connect app like this one, even in dev mode. (Job Composer/`myjobs` supports a dev-directory `.env` because it's a separate standalone Rails engine with its own boot logic; a custom batch-connect app's `form.yml.erb`/`submit.yml.erb` are rendered inside the same Dashboard process regardless of whether the app you're viewing is `dev`, `usr`, or `sys` — only `/etc/ood/config/apps/dashboard/env` affects its `ENV`.) So testing a dev sandbox copy of this app with custom settings still means editing the same root-owned file used in production, then restarting the Dashboard app (**Help → Restart Web Server** from the dashboard) — there's no way around needing admin access for this, even just to test.

**Make sure you're editing this file on the actual OOD web server**, not a Slurm login node — `/etc/ood/config/` can be visible on other hosts via a shared/NFS-mounted path, which makes it easy to edit the file in the right place but restart/check processes on the wrong one, with no PUN or web server process to be found there at all. Check the hostname in your browser's address bar when accessing the OOD dashboard — that's the host that actually needs the edit and the restart.

### Default resource requests

Each resource field's minimum, maximum, and default are all independently overridable, all logic lives in `lib/annex_defaults.rb`:

```sh
# CPUs per node — built-in range 1-128, built-in default 1
HTC_ANNEX_MIN_NUM_CORES=2
HTC_ANNEX_MAX_NUM_CORES=64
HTC_ANNEX_DEFAULT_NUM_CORES=8

# Memory per node (GB) — built-in range 1-512, built-in default 4
HTC_ANNEX_MIN_MEMORY_GB=8
HTC_ANNEX_MAX_MEMORY_GB=256
HTC_ANNEX_DEFAULT_MEMORY_GB=32

# GPUs per node — built-in range 0-8, built-in default 0
HTC_ANNEX_MIN_NUM_GPUS=0
HTC_ANNEX_MAX_NUM_GPUS=4
HTC_ANNEX_DEFAULT_NUM_GPUS=0

# Max wall time (hours) — built-in range 1-72, built-in default 1
HTC_ANNEX_MIN_NUM_HOURS=2
HTC_ANNEX_MAX_NUM_HOURS=48
HTC_ANNEX_DEFAULT_NUM_HOURS=12
```

**`HTC_ANNEX_MIN_MEMORY_GB`'s built-in floor (1 GB) is below the pilot's `MEMORY_CHUNK_SIZE` (3072 MB) — see [Known Limitations](#known-limitations) before relying on it.** An admin who wants to rule out that footgun entirely should set `HTC_ANNEX_MIN_MEMORY_GB=4` (or otherwise ensure it can't drop below ~3 GB).

Any unset or non-numeric value falls back to its built-in counterpart. Each resolved `{min, max, default}` triple is validated as a unit:

- `min` can't go below the resource's hard floor (`1` for cores/memory/wall time, `0` for GPUs — "0 GPUs" is the documented way to request a CPU-only node, so unlike the others it's a valid minimum, not just a fallback).
- `max` must be `>= min`.
- If either of the above is violated, **both** `min` and `max` revert to their built-in values — a broken pair can't be sensibly half-repaired, so rather than guess which bound was wrong, both are discarded together.
- `default` is then clamped into whatever `[min, max]` resulted (admin-supplied or reverted-to-built-in) — a default that's merely out of range gets corrected rather than discarded, since the surrounding `min`/`max` are still trustworthy in that case.

The resolved `min`/`max` are applied directly to the form fields' allowed range, not just used to clamp the default.

### Email notifications

Email notifications (`send_email` / `user_email` fields) only appear on the form if the app believes the cluster can send mail. By default this is autodetected by running `scontrol show config` and checking for a configured `MailProg` — but a configured `MailProg` doesn't guarantee mail actually gets delivered (see [TODO.md](TODO.md)).

To override the autodetection, set:

```sh
# Force email fields on, bypassing autodetection
HTC_ANNEX_EMAIL_ENABLED=true

# Force email fields off, e.g. while a broken mail relay is being fixed
HTC_ANNEX_EMAIL_ENABLED=false
```

Leave it unset to use the `scontrol`-based autodetection.

**`user_email` only hides/shows with the checkbox if `bc_dynamic_js` is enabled instance-wide.** When both fields are shown, `user_email` is meant to appear only once `send_email` is checked (via a `data-hide-user-email-when-un-checked` directive — see [Dynamic Form Widgets](https://osc.github.io/ood-documentation/latest/how-tos/app-development/interactive/dynamic-form-widgets.html)). That directive does nothing at all unless the OOD instance has `bc_dynamic_js: true` set — it defaults to `false`, and without it `user_email` just stays visible regardless of the checkbox. This is a separate instance-wide setting from anything in `/etc/ood/config/apps/dashboard/env` above; it goes in a YAML file under `/etc/ood/config/ondemand.d/` (any filename), e.g.:

```yaml
# /etc/ood/config/ondemand.d/dynamic_forms.yml
bc_dynamic_js: true
```

Same restart requirement as everything else on this page (**Help → Restart Web Server**).

## Session Card Info

`info.html.erb` shows two pieces of info on the session card in "My Interactive Sessions":

- **HTCondor version** (`VERSION`) — read once at submission time (`submit.yml.erb`, via `lib/annex_record.rb`) straight out of `annex.record` inside the tarball (see [Contents of annex-setup.tar](#contents-of-annex-setuptar)). This value is used verbatim by `annex-setup.sh` to pick which HTCondor build to download, so a static read is authoritative — no need to wait for the job to run.
- **Idle-shutdown warning** — the pilot's actual effective `STARTD_NOCLAIM_SHUTDOWN`, converted to a human-readable duration (e.g. "5 minutes") when it resolves to a plain number, falling back to a generic static reminder otherwise.

Two earlier attempts at showing the actual value were tried and abandoned before landing on the current approach:
1. A static read of `annex.record`'s own `STARTD_NOCLAIM_SHUTDOWN` — ruled out because `annex-setup.sh` sources the user's own `~/.condor/annex_config` (a shell override) on top of it before ever using it, and `annex-job-setup.sh` separately copies `~/.condor/annex_pilot_config` in as a higher-precedence HTCondor `config.d` file — both real, supported customization points (see `USER-STEPS.md`) that can silently change the effective value.
2. A live `condor_config_val` query against the running pilot's own downloaded HTCondor install, executed directly from `info.html.erb` — ruled out by a real production `LoadError`: `__dir__` doesn't reliably resolve inside `info.html.erb`'s specific OOD rendering path (`BatchConnect::Session#render_info_view`, different from the one `form.yml.erb`/`submit.yml.erb` use), and passing the app's directory forward via a JSON file (written by `submit.yml.erb`, where `__dir__` *is* reliable) didn't conclusively resolve it in practice.

**The current approach (`lib/annex_pilot_config.rb`) avoids both problems by never touching a live pilot process at all.** Both of the real override points turn out to already be plain text sitting on disk before the pilot ever runs:
- `annex-setup.sh` writes the post-`~/.condor/annex_config`-override value straight into a file, `10-annex-pilot-instance`, in the job's working directory during `before.sh.erb` — i.e. into `staged_root`, well before Slurm even starts the pilot.
- `~/.condor/annex_pilot_config` (the second override point) is a pre-existing user file from the moment the session starts; `annex-job-setup.sh` only `cp`s it in verbatim later, so reading it directly gets the same content without waiting for that copy.

`AnnexPilotConfig.value(staged_root, key)` resolves any config option by scanning `00-annex-pilot-base` (the tarball's shipped default), then `10-annex-pilot-instance`, then `~/.condor/annex_pilot_config`, in that order — the same order and last-definition-wins rule the pilot's own `config.d` uses. This only understands plain `KEY = VALUE` lines, not HTCondor's macro expansion, conditionals, or built-in functions (`$(...)`, `ifThenElse`, etc.); `AnnexPilotConfig.coerce` then attempts `Integer`, then `Float`, then a `true`/`false` match, falling back to the raw string for anything else. `AnnexPilotConfig.shutdown_warning` only humanizes the value when it resolves to a plain `Integer` — anything else (unset, a float, a bool, or a raw expression string) gets the generic static reminder instead.

The one remaining wrinkle: `lib/annex_pilot_config.rb` still needs to reach `info.html.erb` without `require`ing it via `__dir__` (still broken there, per above). `submit.yml.erb` copies the file into `staged_root` (where `__dir__` *is* reliable), and `info.html.erb` `load`s it back by a `staged_root`-based path — `load`, not `require`, so it doesn't matter if `info.html.erb`'s rendering path re-runs this on every card view; the module has no top-level constants for exactly that reason (reassigning one on every `load` would spam "already initialized constant" warnings). `staged_root` itself is still relied on for reading `annex_info.json` (the `condor_version` piece) too — real and confirmed working (traced in `ood/apps/dashboard`'s `BatchConnect::App#submit_opts`, demonstrated in [a community example](https://discourse.openondemand.org/t/customizing-interactive-app-cards-using-erb/2694)), but not part of OOD's documented API for this file — an OOD maintainer has described these card templates as otherwise "pretty locked down." The `load` is wrapped in `rescue StandardError, ScriptError` (`LoadError` is a `ScriptError`, not a `StandardError`) so a failure there just falls back to the static warning; the `annex_info.json` read is a separate `rescue StandardError` so a failure there only omits the version line — neither failure takes down the whole card.

## Logs

- `htc-annex-app.debug` — the OOD job's own stdout/stderr (set via `output_path`/`error_path` in `submit.yml.erb`); mostly the `echo` progress lines from `template/script.sh` and `template/before.sh.erb`.
- `annex-job.out` / `annex-job.err` — stdout/stderr of `hpc.slurm` itself, redirected separately by `template/script.sh`. This is where to look for HTCondor EP startup failures.

## Known Limitations

- `~/.condor/annex_slurm_args` has no effect in this OOD setup. That file is designed for the manual `sbatch` workflow where users edit `hpc.slurm` directly. All Slurm options must be set via the OOD form.
- Each app session submits a single-node Slurm job (one HTCondor EP per launch). Submit multiple sessions to run EPs across multiple nodes.
- `bc_account` and `user_email` are validated against a strict character set before being passed to Slurm (to keep raw form input from corrupting the generated job options). An account or email containing unexpected characters is silently dropped from the submission rather than erroring — if charging/notifications aren't happening, check for typos or unusual characters in those fields first.
- The pilot's base config (`00-annex-pilot-base`, shipped in the tarball) sets `MEMORY_CHUNK_SIZE = 3072` and `MODIFY_REQUEST_EXPR_REQUESTMEMORY = max({ $(MEMORY_CHUNK_SIZE), quantize(RequestMemory, {128}) })` — every job's `RequestMemory` gets rounded up to at least 3072 MB (~3 GB) regardless of what it actually asks for. If a session's total advertised memory is less than that, no job can ever match on it: the EP just sits idle, unclaimed, until `STARTD_NOCLAIM_SHUTDOWN` shuts it down without ever running anything. `HTC_ANNEX_MIN_MEMORY_GB`'s built-in floor is 1 GB, well below this — see [Default resource requests](#default-resource-requests) for the admin override.

## User Documentation

See [USER-STEPS.md](USER-STEPS.md) for end-user instructions.
