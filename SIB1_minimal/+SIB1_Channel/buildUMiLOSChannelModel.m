function channelModel = buildUMiLOSChannelModel(sim, sampleRate)

bsPosition_m = [0; 0; sim.BSHeight_m];
uePosition_m = [sim.Distance_m; 0; sim.UEHeight_m];

pathLossConfig = nrPathLossConfig;
pathLossConfig.Scenario = sim.PathLossScenario;
[pathLoss_dB, shadowFadingStd_dB] = nrPathLoss( ...
    pathLossConfig, sim.CenterFrequency_Hz, true, bsPosition_m, uePosition_m);

maximumDopplerShift_Hz = sim.UEVelocity_mps * sim.CenterFrequency_Hz / ...
    physconst('LightSpeed');

channelModel = struct();
channelModel.PathLossScenario = sim.PathLossScenario;
channelModel.BSPosition_m = bsPosition_m;
channelModel.UEPosition_m = uePosition_m;
channelModel.BasePathLoss_dB = pathLoss_dB;
channelModel.PathLoss_dB = pathLoss_dB;
channelModel.ShadowFadingStd_dB = shadowFadingStd_dB;
channelModel.DelayProfile = sim.DelayProfile;
channelModel.DelaySpread_s = sim.DelaySpread_s;
channelModel.MaximumDopplerShift_Hz = maximumDopplerShift_Hz;
channelModel.SampleRate = sampleRate;

channelModel.NormalizePathGains = true;
channelModel.NormalizeChannelOutputs = false;
channelModel.LOS = true;

end
