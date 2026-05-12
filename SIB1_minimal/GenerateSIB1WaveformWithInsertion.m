function [txWaveform, meta] = GenerateSIB1WaveformWithInsertion(config, pilotStrategy)

% Build the standard SSB/SIB1 waveform, then add the sensing-pilot delta.
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'NRCellSearchMIBAndSIB1RecoveryExample'));

wavegenConfig = hSIB1WaveformConfiguration(config);

[baseWaveform, waveInfo] = nrWaveformGenerator(wavegenConfig);

[bwpGridWithInsertion, ~, insertionMask, insertionStats] = ...
    Cal_SensingGrid(config, pilotStrategy);

carrierGrid = waveInfo.ResourceGrids.ResourceGridInCarrier;
bwpGrid = waveInfo.ResourceGrids.ResourceGridBWP;

carrierCfg = wavegenConfig.SCSCarriers{1};
bwpCfg = wavegenConfig.BandwidthParts{1};

% Map the BWP insertion delta back into the full carrier grid.
rowStart = (bwpCfg.NStartBWP - carrierCfg.NStartGrid) * 12 + 1;
rowEnd = rowStart + size(bwpGrid, 1) - 1;

insertionOnlyBWPGrid = bwpGridWithInsertion - bwpGrid;

insertionOnlyCarrierGrid = complex(zeros(size(carrierGrid)));
insertionOnlyCarrierGrid(rowStart:rowEnd, :) = insertionOnlyBWPGrid;

finalCarrierGrid = carrierGrid + insertionOnlyCarrierGrid;

% Remodulate only the inserted resources and add them to the base waveform.
carrier = nrCarrierConfig;
carrier.NCellID = config.NCellID;
carrier.SubcarrierSpacing = carrierCfg.SubcarrierSpacing;
carrier.NSizeGrid = carrierCfg.NSizeGrid;
carrier.NStartGrid = carrierCfg.NStartGrid;
carrier.CyclicPrefix = 'normal';
carrier.NSlot = 0;
carrier.NFrame = 0;

insertionWaveform = nr5g.internal.wavegen.nrOFDMModulateCallForCodegen( ...
    carrier, insertionOnlyCarrierGrid, carrierCfg.SubcarrierSpacing, ...
    carrier.CyclicPrefix, 0, waveInfo.ResourceGrids.Info.SampleRate, 0);

if size(insertionWaveform, 1) < size(baseWaveform, 1)
    insertionWaveform(end + 1:size(baseWaveform, 1), :) = 0;
elseif size(insertionWaveform, 1) > size(baseWaveform, 1)
    insertionWaveform = insertionWaveform(1:size(baseWaveform, 1), :);
end

txWaveform = baseWaveform + insertionWaveform;
ofdmInfo = waveInfo.ResourceGrids.Info;

% Active samples define the power-normalization interval.
activeSymbolMask = any(abs(finalCarrierGrid) > 0, 1);

symbolLengthPattern = ofdmInfo.SymbolLengths(:).';
numSymbols = size(finalCarrierGrid, 2);
repeats = ceil(numSymbols / numel(symbolLengthPattern));
symbolLengthsAll = repmat(symbolLengthPattern, 1, repeats);
symbolLengthsAll = symbolLengthsAll(1:numSymbols);

waveformLength = size(txWaveform, 1);
activeSampleMask = false(waveformLength, 1);
sampleHead = 1;

for symIdx = 1:numSymbols
    sampleTail = min(sampleHead + symbolLengthsAll(symIdx) - 1, waveformLength);

    if activeSymbolMask(symIdx)
        activeSampleMask(sampleHead:sampleTail) = true;
    end

    sampleHead = sampleTail + 1;
    if sampleHead > waveformLength
        break;
    end
end

occupiedCarrierBandwidth_Hz = carrierCfg.NSizeGrid * 12 * ...
    carrierCfg.SubcarrierSpacing * 1e3;

% Keep intermediate grids in meta for debugging and reporting.
meta = struct();
meta.PilotStrategy = pilotStrategy;
meta.BaseWaveform = baseWaveform;
meta.CarrierGrid = carrierGrid;
meta.BWPGridOriginal = bwpGrid;
meta.BWPGridWithInsertion = bwpGridWithInsertion;
meta.InsertionOnlyBWPGrid = insertionOnlyBWPGrid;
meta.InsertionOnlyCarrierGrid = insertionOnlyCarrierGrid;
meta.InsertionWaveform = insertionWaveform;
meta.FinalCarrierGrid = finalCarrierGrid;
meta.BWPRowRange = [rowStart rowEnd];
meta.InsertionMask = insertionMask;
meta.InsertionStats = insertionStats;
meta.WavegenConfig = wavegenConfig;
meta.WaveInfo = waveInfo;
meta.OFDMInfo = ofdmInfo;
meta.SampleRate = ofdmInfo.SampleRate;
meta.ActiveSymbolMask = activeSymbolMask;
meta.ActiveSampleMask = activeSampleMask;
meta.SymbolLengthsAll = symbolLengthsAll;
meta.OccupiedCarrierBandwidth_Hz = occupiedCarrierBandwidth_Hz;

meta.RefBurst = struct( ...
    'BlockPattern', config.BlockPattern, ...
    'L_max', numel(config.TransmittedBlocks));

end
