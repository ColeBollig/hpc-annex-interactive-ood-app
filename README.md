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

## Known Limitations

- `~/.condor/annex_slurm_args` has no effect in this OOD setup. That file is designed for the manual `sbatch` workflow where users edit `hpc.slurm` directly. All Slurm options must be set via the OOD form.
- Each app session submits a single-node Slurm job (one HTCondor EP per launch). Submit multiple sessions to run EPs across multiple nodes.

## User Documentation

See [USER-STEPS.md](USER-STEPS.md) for end-user instructions.
