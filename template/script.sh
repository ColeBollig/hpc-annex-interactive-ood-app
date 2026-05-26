#!/bin/bash

echo ""
echo "Executing HTC annex slurm script"
bash hpc.slurm > annex-job.out 2> annex-job.err
