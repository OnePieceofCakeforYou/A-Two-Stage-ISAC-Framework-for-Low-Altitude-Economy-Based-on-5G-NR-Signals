function largeScale = sampleLargeScaleLosses(sim, channelModel, seed)

rs = RandStream('mt19937ar', 'Seed', seed);

shadowFading_dB = 0;
if isfield(sim, 'EnableShadowFading') && sim.EnableShadowFading
    shadowFading_dB = channelModel.ShadowFadingStd_dB * randn(rs, 1);
end

blockageLoss_dB = 0;
if isfield(sim, 'EnableBlockageLoss') && sim.EnableBlockageLoss
    if rand(rs, 1) < sim.BlockageProbability
        blockageLoss_dB = sim.BlockageLoss_dB;
    end
end

implementationLoss_dB = 0;
if isfield(sim, 'ImplementationLoss_dB')
    implementationLoss_dB = sim.ImplementationLoss_dB;
end

largeScale = struct();
largeScale.ShadowFading_dB = shadowFading_dB;
largeScale.BlockageLoss_dB = blockageLoss_dB;
largeScale.ImplementationLoss_dB = implementationLoss_dB;
largeScale.TotalPathLoss_dB = channelModel.PathLoss_dB + shadowFading_dB + ...
    blockageLoss_dB + implementationLoss_dB;

end
