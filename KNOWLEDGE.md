# HTC Annex — Internal Knowledge

Implementation details and mechanism-level gotchas for anyone maintaining or extending this app. None of this is needed to install or use it — see [README.md](README.md) for that, or [USER-STEPS.md](USER-STEPS.md) for end-user instructions.

## App Files

| File | Purpose |
|------|---------|
| `manifest.yml` | OOD app metadata (name, category, icon) |
| `form.yml.erb` | OOD form definition — resource controls shown to the user |
| `submit.yml.erb` | Maps form values to Slurm job parameters |
| `lib/annex_defaults.rb` | Shared admin-configuration resolution (resource min/max/default, email support), `require`d by both `form.yml.erb` and `submit.yml.erb` |
| `lib/annex_record.rb` | Reads `annex.record` out of the user's selected tarball without a full extract; `require`d by `submit.yml.erb` |
| `lib/annex_pilot_config.rb` | Resolves the pilot's effective `STARTD_NOCLAIM_SHUTDOWN` from static config fragments (see [Session Card Info Mechanism](#session-card-info-mechanism)); copied into `staged_root` by `submit.yml.erb`, `load`ed back by `info.html.erb` |
| `info.html.erb` | Extra info shown on the session card |
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

## Slurm Script Internals

`annex-setup.sh` generates `hpc.slurm`, but because OOD runs it as `bash hpc.slurm` rather than submitting it via `sbatch`, the `#SBATCH` headers in that file are inert comments. All resource allocation is handled by OOD through `submit.yml.erb`'s native Slurm options instead.

`annex-node.sh` reads Slurm environment variables (`SLURM_CPUS_ON_NODE`, `SLURM_MEM_PER_NODE`, `SLURM_JOB_END_TIME`) to configure what the HTCondor EP advertises to the pool.

## Session Card Info Mechanism

`STARTD_NOCLAIM_SHUTDOWN` can be overridden twice before the pilot ever applies it — via `~/.condor/annex_config` (a shell override) and `~/.condor/annex_pilot_config` (an HTCondor `config.d` file), both real, supported customization points (see `USER-STEPS.md`). `lib/annex_pilot_config.rb`'s `AnnexPilotConfig.value(staged_root, key)` resolves the effective value by scanning, in order, `00-annex-pilot-base` (the tarball's shipped default), `10-annex-pilot-instance` (written into `staged_root` during setup, already reflecting the `annex_config` override), and `~/.condor/annex_pilot_config` directly — the same order and last-definition-wins rule the pilot's own `config.d` uses, without needing to query a running pilot.

This only understands plain `KEY = VALUE` lines, not HTCondor's macro expansion, conditionals, or built-in functions (`$(...)`, `ifThenElse`, etc.). `AnnexPilotConfig.coerce` attempts `Integer`, then `Float`, then a `true`/`false` match, falling back to the raw string for anything else; `AnnexPilotConfig.shutdown_warning` only humanizes the value into a duration when it resolves to a plain `Integer` — anything else (unset, a float, a bool, or a raw expression string) gets the generic static reminder instead.

## MEMORY_CHUNK_SIZE

The pilot's base config (`00-annex-pilot-base`, shipped in the tarball) sets:

```
MEMORY_CHUNK_SIZE = 3072
MODIFY_REQUEST_EXPR_REQUESTMEMORY = max({ $(MEMORY_CHUNK_SIZE), quantize(RequestMemory, {128}) })
```

Every job's `RequestMemory` gets rounded up to at least 3072 MB (~3 GB) regardless of what it actually asks for. If a session's total advertised memory is less than that, no job can ever match on it: the EP just sits idle, unclaimed, until `STARTD_NOCLAIM_SHUTDOWN` shuts it down without ever running anything. `HTC_ANNEX_MIN_MEMORY_GB`'s built-in floor is 1 GB, well below this.
