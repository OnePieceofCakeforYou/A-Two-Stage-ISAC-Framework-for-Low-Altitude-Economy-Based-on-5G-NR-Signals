# A Two-Stage ISAC Framework for Low-Altitude Economy Based on 5G NR Signals

This repository collects MATLAB code used around the paper:

> **"A Two-Stage ISAC Framework for Low-Altitude Economy Based on 5G NR Signals"**

The code is organized into two complementary parts:

- Baseline sensing algorithms for range-Doppler or angle-estimation comparisons.
- A compact 5G NR SIB1 link-level communication simulation for evaluating how sensing-pilot insertion affects initial-access decoding.

## Repository Contents

| Folder | Purpose |
| --- | --- |
| `+2D_MUSIC` | 2D-MUSIC baseline for high-resolution parameter estimation. |
| `+CSAN` | Compressive-sensing atomic-norm baseline. |
| `SIB1_minimal` | Link-level SSB/SIB1 communication simulation with optional sensing-pilot insertion. |

## Baseline Sensing Algorithms

The baseline algorithms provide classical and state-of-the-art references for evaluating the proposed two-stage ISAC framework under comparable 5G NR waveform and channel settings.

### 2D-FFT

A conventional two-dimensional Fast Fourier Transform method for estimating range and Doppler, or angle-related profiles. It is widely used because of its low computational complexity.

Reference:

> L. Pucci, E. Paolini, and A. Giorgetti, "System-level analysis of joint sensing and communication based on 5G new radio," *IEEE J. Sel. Areas Commun.*, vol. 40, no. 7, pp. 2043-2055, 2022.

### 2D-MUSIC

A high-resolution subspace-based method that extends MUSIC to two-dimensional parameter estimation. It can provide finer resolution than FFT-based methods, especially in low-SNR regimes.

Reference:

> R. Xie, D. Hu, K. Luo, and T. Jiang, "Performance analysis of joint range-velocity estimator with 2D-MUSIC in OFDM radar," *IEEE Trans. Signal Process.*, vol. 69, pp. 4787-4800, 2021.

### 2D CS-AN

A super-resolution method based on atomic-norm minimization for gridless parameter estimation in continuous delay-Doppler domains.

Reference:

> L. Zheng and X. Wang, "Super-resolution delay-doppler estimation for OFDM passive radar," *IEEE Trans. Signal Process.*, vol. 65, no. 9, pp. 2197-2210, 2017.

## SIB1 Link-Level Communication Simulation

The `SIB1_minimal` folder contains a compact MATLAB link-level simulation program for evaluating the communication-side impact of inserting sensing pilot resources into a 5G NR Synchronization Signal Block (SSB) and System Information Block 1 (SIB1) waveform.

In this simulation, SIB1 carries the Remaining Minimum System Information (RMSI) needed by a user equipment during initial access. The receiver chain therefore tests whether the waveform can support the full path:

```text
SSB synchronization -> PBCH/MIB decoding -> PDCCH/DCI decoding -> PDSCH/SIB1 decoding
```

The simulation compares SIB1 access and decoding success rates under two pilot strategies:

- `None`: standard SSB + Remaining Minimum System Information (RMSI) / SIB1 waveform without additional sensing pilots.
- `Sparse`: SSB + RMSI/SIB1 waveform with sparse sensing pilot resource-element insertion.

The workflow generates the transmit waveform, applies a 3GPP UMi LOS large-scale channel, TDL-D fading, swept transmit-beam gain, shadow fading, and receiver noise, then measures BCH, DCI, SIB1, and overall access success rates.

Run the simulation from MATLAB:

```matlab
cd SIB1_minimal
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

See [`SIB1_minimal/README.md`](SIB1_minimal/README.md) for more details.

## Required MATLAB Products

The SIB1 link-level simulation requires:

- MATLAB
- 5G Toolbox
- Communications Toolbox
- Phased Array System Toolbox
- Signal Processing Toolbox
- Parallel Computing Toolbox

Parallel Computing Toolbox is used for the full Monte Carlo sweep. The smoke-test configuration above disables parallel execution.
