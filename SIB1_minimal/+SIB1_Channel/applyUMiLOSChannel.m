function rxWaveform = applyUMiLOSChannel( ...
    txWaveform, channelModel, beamProfile, seed, pathLoss_dB)

% Apply TDL fading, swept-beam gain, and large-scale path loss.
if nargin < 5
    pathLoss_dB = channelModel.PathLoss_dB;
end

tdl = nrTDLChannel;
tdl.DelayProfile = channelModel.DelayProfile;
tdl.DelaySpread = channelModel.DelaySpread_s;
tdl.MaximumDopplerShift = channelModel.MaximumDopplerShift_Hz;
tdl.NumTransmitAntennas = 1;
tdl.NumReceiveAntennas = 1;
tdl.SampleRate = channelModel.SampleRate;
tdl.NormalizePathGains = channelModel.NormalizePathGains;
tdl.NormalizeChannelOutputs = channelModel.NormalizeChannelOutputs;
tdl.RandomStream = 'mt19937ar with seed';
tdl.Seed = seed;
tdl.ChannelFiltering = true;

rxFaded = tdl(single(txWaveform));

gainMask = beamProfile.SampleGainAmplitude(1:size(rxFaded, 1), :);
rxBeamformed = double(rxFaded) .* gainMask;

largeScaleAmplitude = 10^(-pathLoss_dB / 20);
rxWaveform = largeScaleAmplitude * rxBeamformed;

end
