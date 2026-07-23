#!/bin/bash

echo ""
echo "Executing HTC annex slurm script"

# OOD submits this job's batch script with restricted environment export
# (SLURM_EXPORT_ENV=NONE), which silently strips custom exported variables
# (e.g. ANNEX_JOBID) from any srun step nested inside hpc.slurm/annex-node.sh.
# Force full propagation so the annex's own srun calls behave the same as a
# manually-submitted `sbatch hpc.slurm`.
export SLURM_EXPORT_ENV=ALL

bash hpc.slurm > annex-job.out 2> annex-job.err
status=$?
echo "hpc.slurm exited with status ${status}"
exit "${status}"
