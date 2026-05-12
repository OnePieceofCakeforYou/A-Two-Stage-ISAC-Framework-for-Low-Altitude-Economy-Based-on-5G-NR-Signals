function sim = buildSimConfig(runMode, simOverrides)

% Central simulation defaults; callers can override any field.
sim = struct();

sim.Distance_m              = 20;
sim.CenterFrequency_Hz      = 30e9;
sim.PathLossScenario        = 'UMi';
sim.BSHeight_m              = 10;
sim.UEHeight_m              = 1.5;
sim.UEVelocity_mps          = 3 / 3.6;

sim.NoisePSD_dBmHz          = -174;
sim.ReceiverNoiseFigure_dB  = 7;
sim.RFFrontEndBandwidth_Hz  = 100e6;

sim.DelayProfile            = 'TDL-D';
sim.DelaySpread_s           = 30e-9;
sim.EnableShadowFading      = true;

sim.NumTransmitAntennas     = 32;
sim.RandomizeUEAzimuth      = true;
sim.UEAzimuthRange_deg      = [-60 60];

nominalElevation_deg = rad2deg(atan2( ...
    sim.UEHeight_m - sim.BSHeight_m, sim.Distance_m));

sim.TxAzSweep_deg           = [-60 60];
sim.TxElSweep_deg           = [nominalElevation_deg nominalElevation_deg];
sim.ElevationSweep          = true;

sim.PilotStrategies         = {'None', 'Sparse'};
sim.CoarseTxPower_dBm       = -30:5:10;
sim.NumMonteCarloCoarse     = 200;
sim.NumMonteCarloFine       = 200;
sim.FineSweepLead_dB        = 1;
sim.FineSweepTrail_dB       = 4;

sim.UseParallelCoarse       = false;
sim.UseParallelFine         = true;
sim.NumWorkers              = 50;

sim.ChannelSeedBase         = 310000;
sim.NoiseSeedBase           = 910000;
sim.GeometrySeedBase        = 510000;
sim.LargeScaleSeedBase      = 710000;

if runMode == "quick"
    sim.CoarseTxPower_dBm   = -20:2:-16;
    sim.NumMonteCarloCoarse = 1;
    sim.NumMonteCarloFine   = 2;
    sim.FineSweepLead_dB    = 0;
    sim.FineSweepTrail_dB   = 2;
    sim.UseParallelCoarse   = false;
    sim.UseParallelFine     = false;
    sim.NumWorkers          = [];
end

if isempty(fieldnames(simOverrides))
    return;
end

overrideFields = fieldnames(simOverrides);
for fieldIdx = 1:numel(overrideFields)
    sim.(overrideFields{fieldIdx}) = simOverrides.(overrideFields{fieldIdx});
end

end
