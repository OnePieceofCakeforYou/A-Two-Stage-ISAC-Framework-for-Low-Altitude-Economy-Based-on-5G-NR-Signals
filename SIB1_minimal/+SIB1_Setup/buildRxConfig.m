function rxConfig = buildRxConfig(sampleRate, config, referenceMeta)

rxConfig = struct();

rxConfig.SampleRate = sampleRate;

rxConfig.FPhaseComp = 0;

rxConfig.MinChannelBW = config.MinChannelBW;
rxConfig.RefBurst = referenceMeta.RefBurst;

rxConfig.NormalizeRxGrid = false;

end
