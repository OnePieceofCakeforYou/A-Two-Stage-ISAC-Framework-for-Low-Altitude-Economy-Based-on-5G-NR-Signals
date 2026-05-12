function config = buildWaveformConfig()

config = struct();

config.NCellID = 102;

config.BlockPattern = 'Case D';

config.TransmittedBlocks = ones(1, 64);

config.SubcarrierSpacingCommon = 120;
config.EnableSIB1 = 1;
config.MinChannelBW = 100;

config.Power = zeros(size(config.TransmittedBlocks));

end
