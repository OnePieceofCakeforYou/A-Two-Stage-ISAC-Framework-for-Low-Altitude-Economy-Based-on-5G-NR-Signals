function [success, bchSuccess, dciSuccess, sib1Success] = runOneTrial( ...
    sim, txPower_dBm, txWaveformUnit, meta, config, channelModel, ...
    noisePower_W, rxConfig, seedOffset, stratIdx, powerIdx, runIdx)

% Run one strategy/power/trial point through channel, noise, and receiver.
txPower_W = 10^((txPower_dBm - 30) / 10);
txWaveform = sqrt(txPower_W) * txWaveformUnit;

seedBaseOffset = seedOffset + 10000 * (stratIdx - 1) + 100 * (powerIdx - 1) + runIdx;
channelSeed = sim.ChannelSeedBase + seedBaseOffset;
noiseSeed = sim.NoiseSeedBase + seedBaseOffset;
geometrySeed = sim.GeometrySeedBase + seedBaseOffset;
largeScaleSeed = sim.LargeScaleSeedBase + seedBaseOffset;

% Geometry, beam sweep, and large-scale loss are randomized per trial.
userAzimuth_deg = SIB1_Beam.sampleUEAzimuthDeg(sim, geometrySeed);
beamProfile = SIB1_Beam.buildSSBBeamSweepProfile(sim, config, meta, userAzimuth_deg);
trialLargeScale = SIB1_Channel.sampleLargeScaleLosses(sim, channelModel, largeScaleSeed);

rxWaveformClean = SIB1_Channel.applyUMiLOSChannel( ...
    txWaveform, channelModel, beamProfile, channelSeed, ...
    trialLargeScale.TotalPathLoss_dB);

noise = SIB1_Channel.generateComplexGaussianNoise( ...
    size(rxWaveformClean), noisePower_W, noiseSeed);
metrics = RecoverSIB1FromWaveform(rxWaveformClean + noise, rxConfig);

success = logical(metrics.Success);
bchSuccess = logical(metrics.BCHSuccess);
dciSuccess = logical(metrics.DCISuccess);
sib1Success = logical(metrics.SIB1Success);

end
