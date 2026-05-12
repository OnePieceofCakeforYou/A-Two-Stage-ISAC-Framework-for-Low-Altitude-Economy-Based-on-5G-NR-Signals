function results = buildResults( ...
    sim, config, sampleRate, activeDutyCycle, noiseInfo, channelModel, ...
    beamProfileRef, waveformMeta, coarseResults, fineResults)

results = struct();

results.SimConfig = sim;
results.WaveformConfig = config;
results.SampleRate = sampleRate;
results.ActiveDutyCycle = activeDutyCycle;
results.ActiveDutyCyclePercent = 100 * activeDutyCycle;

results.PowerDefinition = sprintf([ ...
    'Average total conducted power over the active waveform interval, ' ...
    'summed across all %d Tx antennas'], sim.NumTransmitAntennas);

results.NoiseDensityWithNF_dBmHz = noiseInfo.DensityWithNF_dBmHz;
results.NoisePower_dBm = noiseInfo.Power_dBm;
results.RFFrontEndBandwidth_Hz = sim.RFFrontEndBandwidth_Hz;
results.ChannelModel = channelModel;
results.BeamProfile = beamProfileRef;
results.UEAzimuthRandomization = struct( ...
    'Enabled', sim.RandomizeUEAzimuth, ...
    'Range_deg', sim.UEAzimuthRange_deg, ...
    'ReferenceAzimuth_deg', beamProfileRef.UserAngle_deg(1));
results.RealisticChannelAssumptions = struct( ...
    'EnableShadowFading', sim.EnableShadowFading, ...
    'ShadowFadingStd_dB', channelModel.ShadowFadingStd_dB);
results.WaveformMeta = waveformMeta;

results.CoarseResults = coarseResults;
results.FineResults = fineResults;

end
