# HTC Annex OOD App — TODO

## In Progress / Next Up

- [ ] Figure out annex time issues
- [ ] Figure out email/start/stop issues
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
