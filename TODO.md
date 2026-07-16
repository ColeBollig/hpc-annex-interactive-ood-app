# HTC Annex OOD App — TODO

## In Progress / Next Up

- [ ] Figure out annex time issues
- [ ] Email/start/stop notifications not arriving — confirmed cluster-side, not an app bug:
      `submit.yml.erb` correctly generates `--mail-type=BEGIN,END --mail-user=...` (verified in a
      failed run's `job_script_options.json`), and a plain `sbatch --mail-type=BEGIN,END
      --mail-user=... --wrap="sleep 10"` submitted directly on spark-login (bypassing the OOD app
      entirely) also produced no email. `scontrol show config` shows `MailProg=/bin/mail`, but the
      Slurm controller likely has no working outbound mail relay. Needs CHTC admin follow-up
      (check maillog on the node running slurmctld) — nothing left to fix in this repo.
- [ ] Test full loop: place job on AP, create annex, move tarball to HPC, launch via OOD, confirm job exits cleanly
- [ ] Get Ian to handle the user-facing documentation and onboarding
- [ ] Demo to Miron
- [ ] Package app into a git repo
- [ ] Share interactive app with users

## Open Questions

- [ ] `~/.condor/annex_slurm_args` has no effect with the OOD interactive app setup — the OOD form controls all `#SBATCH` options. Decide if this needs a workaround or if the form fields are sufficient.
- [ ] Explore how user-specified resource inputs (CPUs, memory, wall time) propagate to pilot job advertisements visible in HTCondor — confirm EPs advertise what the form requested.

## Completed

- [x] Make annex source tarball the first form field
- [x] Define defaults, min, max, step for all numeric fields
- [x] Apply all form inputs to `submit.yml.erb` (CPUs, memory, GPUs, wall time, account, email)
- [x] Make partition selection dynamic via `auto_queues` (no hardcoded partition list)
- [x] Make cluster selection dynamic via `cluster: "*"` (works on any OOD-configured Slurm system)
