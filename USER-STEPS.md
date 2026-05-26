# Running an HTC Annex via Open OnDemand

## Steps

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

---

## User Customization

These optional files in `~/.condor/` are read by the annex setup and pilot scripts at runtime.

### `~/.condor/annex_config`

Sourced by `annex-setup.sh` before the Slurm job script is written. Use it to load modules or override the `SCRATCH` variable (which controls where the `pilot.<jobid>` working directory is created — useful for redirecting to node-local scratch).

### `~/.condor/annex_slurm_args`

> **Note:** This file has no effect when using the OOD interactive app. All Slurm resource options are controlled by the OOD form. This file is only relevant when submitting `hpc.slurm` manually via `sbatch`.

When used manually, the contents are inserted into `hpc.slurm` just after the base `#SBATCH` lines, allowing additional options and pre-launch commands.

### `~/.condor/annex_pilot_config`

Contents are copied into the EP's `config.d/` directory, allowing per-user HTCondor configuration on the execute point.
