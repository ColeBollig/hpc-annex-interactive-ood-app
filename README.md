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

All resource allocation (CPUs, memory, GPUs, wall time) is controlled through the OOD form (`submit.yml.erb`), not by editing the generated Slurm job script directly. See [KNOWLEDGE.md](KNOWLEDGE.md) for implementation details.

## Usage

### 1. On the HTCondor Access Point

Submit your job(s) targeting a named annex, then create the annex:

```sh
htcondor job submit my-job.sub --annex-name <NAME>
htcondor annex create <NAME>
```

This produces an `annex-setup.tar` tarball containing everything needed to start the annex on the HPC cluster.

### 2. Copy the Tarball to the HPC System

The tarball can live anywhere in your home directory. Renaming it to `<NAME>.tar` is recommended for clarity.

**Option A — scp directly to the HPC login node:**
```sh
scp annex-setup.tar <user>@<hpc-login>:~/<NAME>.tar
```

**Option B — via local machine and OOD file upload:**
```sh
scp annex-setup.tar <local-machine>:~/
# Then use the OOD Files app to upload it to your home directory
```

### 3. Launch the HTC Annex App in OOD

1. Open **Interactive Apps** and select **HTC Annex**
2. Fill out the resource form (cluster, partition, CPUs, memory, wall time, etc.)
3. In the **Annex source tarball** field, enter the full path to the tarball uploaded in Step 2 — e.g. `~/my-annex.tar`
4. Click **Launch**

OOD will submit a Slurm job that extracts the tarball, downloads the HTCondor binaries, and starts the execute point (EP). Your queued HTCondor jobs will begin running once the EP connects to the collector.

### User Customization

These optional files in `~/.condor/` are read by the annex setup and pilot scripts at runtime.

**`~/.condor/annex_config`** — sourced by `annex-setup.sh` before the Slurm job script is written. Use it to load modules or override the `SCRATCH` variable (which controls where the `pilot.<jobid>` working directory is created — useful for redirecting to node-local scratch).

**`~/.condor/annex_slurm_args`** — has no effect when using the OOD interactive app. All Slurm resource options are controlled by the OOD form. This file is only relevant when submitting `hpc.slurm` manually via `sbatch`, where its contents are inserted just after the base `#SBATCH` lines.

**`~/.condor/annex_pilot_config`** — contents are copied into the EP's `config.d/` directory, allowing per-user HTCondor configuration on the execute point.

## Admin Configuration

All settings below are read from `/etc/ood/config/apps/dashboard/env` (managed by the OOD admin, not part of this repo). Interactive apps like this one are all rendered by the single Dashboard Passenger process, so this file — not a per-app one — is where their environment variables live; it's shared across every interactive app on the instance, not exclusive to HTC Annex.

**This is also true for a personal dev/sandbox copy of this app** (`~/ondemand/dev/<name>/`) — there is no per-app `.env`/`env` file for a batch-connect app like this one, even in dev mode. So testing a dev sandbox copy of this app with custom settings still means editing the same root-owned file used in production, then restarting the Dashboard app (**Help → Restart Web Server** from the dashboard) — there's no way around needing admin access for this, even just to test.

**Make sure you're editing this file on the actual OOD web server**, not a Slurm login node — `/etc/ood/config/` can be visible on other hosts via a shared/NFS-mounted path, which makes it easy to edit the file in the right place but restart/check processes on the wrong one, with no PUN or web server process to be found there at all. Check the hostname in your browser's address bar when accessing the OOD dashboard — that's the host that actually needs the edit and the restart.

### Default resource requests

Each resource field's minimum, maximum, and default are all independently overridable:

```sh
# CPUs per node — built-in range 1-128, built-in default 1
HTC_ANNEX_MIN_NUM_CORES=2
HTC_ANNEX_MAX_NUM_CORES=64
HTC_ANNEX_DEFAULT_NUM_CORES=8

# Memory per node (GB) — built-in range 4-512, built-in default 4
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

**Don't set `HTC_ANNEX_MIN_MEMORY_GB` below `4`.** The built-in minimum is already 4 GB for this reason — going lower allows sessions with too little memory for any job to ever run on them (see [Known Limitations](#known-limitations)).

Any unset or non-numeric value falls back to its built-in counterpart. An invalid `min`/`max` pair (min below the resource's hard floor, or max < min) reverts both to their built-in values; a `default` outside the resulting range is clamped into it instead of discarded. The resolved `min`/`max` are applied directly to the form fields' allowed range, not just used to clamp the default.

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

**`user_email` only hides/shows with the checkbox if `bc_dynamic_js` is enabled instance-wide.** This is a separate, instance-wide setting from anything in `/etc/ood/config/apps/dashboard/env` above; it goes in a YAML file under `/etc/ood/config/ondemand.d/` (any filename), e.g.:

```yaml
# /etc/ood/config/ondemand.d/dynamic_forms.yml
bc_dynamic_js: true
```

Without it, `user_email` just stays visible regardless of the `send_email` checkbox. Same restart requirement as everything else on this page (**Help → Restart Web Server**).

## Session Card Info

The session card in "My Interactive Sessions" shows two extra pieces of info once available:

- **HTCondor version** that will be downloaded and run.
- **Idle-shutdown warning** — how long the execute point can sit unclaimed before it shuts itself down, as an actual duration (e.g. "5 minutes") when that can be determined, or a generic reminder otherwise.

## Logs

- `htc-annex-app.debug` — the OOD job's own stdout/stderr; mostly setup progress messages.
- `annex-job.out` / `annex-job.err` — stdout/stderr of the HTCondor pilot itself. This is where to look for EP startup failures.

## Known Limitations

- `~/.condor/annex_slurm_args` has no effect in this OOD setup. That file is designed for the manual `sbatch` workflow where users edit the generated Slurm script directly. All Slurm options must be set via the OOD form.
- Each app session submits a single-node Slurm job (one HTCondor EP per launch). Submit multiple sessions to run EPs across multiple nodes.
- `bc_account` and `user_email` are validated against a strict character set before being passed to Slurm. An account or email containing unexpected characters is silently dropped from the submission rather than erroring — if charging/notifications aren't happening, check for typos or unusual characters in those fields first.
- A session needs at least ~3 GB of total memory for any job to be able to run on it — less than that and the EP just sits idle, unclaimed, until it shuts itself down without ever running anything. The built-in minimum (4 GB) already accounts for this; don't override `HTC_ANNEX_MIN_MEMORY_GB` below it (see [Default resource requests](#default-resource-requests), and [KNOWLEDGE.md](KNOWLEDGE.md) for why).
