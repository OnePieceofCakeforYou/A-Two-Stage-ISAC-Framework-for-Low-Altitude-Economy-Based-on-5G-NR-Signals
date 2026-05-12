# SIB1 Link-Level Simulation

This folder contains a compact MATLAB link-level simulation for evaluating
the communication impact of inserting sensing pilot resources into a 5G NR
SSB/SIB1 waveform.

The main workflow compares the end-to-end SIB1 access and decoding success
rate for two pilot strategies:

- `None`: standard SSB + RMSI/SIB1 waveform without additional sensing pilots.
- `Sparse`: SSB + RMSI/SIB1 waveform with sparse sensing pilot RE insertion.

The simulation generates the transmit waveform, applies a 3GPP UMi LOS
large-scale channel, TDL-D fading, swept transmit-beam gain, shadow fading,
and receiver noise, then runs the SSB/PBCH/PDCCH/PDSCH recovery chain to
measure BCH, DCI, SIB1, and overall access success rates.

## Entry Point

Run the default simulation from MATLAB:

```matlab
main
```

For a short smoke test:

```matlab
mainArgs = {'quick', struct( ...
    'NumMonteCarloFine', 1, ...
    'UseParallelFine', false, ...
    'UseParallelCoarse', false, ...
    'NumWorkers', [])};
main
```

The main orchestration function is:

```matlab
Run_SIB1_SuccessRate_NoneVsSparse_Parfor
```

## Outputs

The simulation writes the following files in this folder when it runs:

- `sib1_success_rate_none_vs_sparse_parfor.mat`
- `sib1_success_rate_none_vs_sparse_parfor.fig`
- `sib1_success_rate_none_vs_sparse_parfor.png`

## Required MATLAB Products

The code was checked with MATLAB's dependency analysis and requires:

- MATLAB
- 5G Toolbox
- Communications Toolbox
- Phased Array System Toolbox
- Signal Processing Toolbox
- Parallel Computing Toolbox

Parallel Computing Toolbox is used for the full Monte Carlo sweep. The quick
smoke-test configuration above disables parallel execution.
