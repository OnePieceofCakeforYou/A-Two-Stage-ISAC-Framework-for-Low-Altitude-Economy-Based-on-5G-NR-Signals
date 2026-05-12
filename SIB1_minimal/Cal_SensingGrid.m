function [sensingGrid_full, gridWithSensing, mask, stats] = Cal_SensingGrid(config, pilotStrategy)

% Insert sensing pilots into the SIB1 BWP while avoiding communication REs.
wavegenConfig = hSIB1WaveformConfiguration(config);
[~, waveInfo] = nrWaveformGenerator(wavegenConfig);

bwpGrid = waveInfo.ResourceGrids.ResourceGridBWP;

symbolsPerSlot = 14;

firstSearchSpace = wavegenConfig.SearchSpaces{1, 1};
slotInfo = firstSearchSpace.SlotPeriodAndOffset;
startSlot = slotInfo(2);
startSymbol = firstSearchSpace.StartSymbolWithinSlot;
StartSymbol = startSlot * symbolsPerSlot + startSymbol + 1;

lastPDSCH_Config = wavegenConfig.PDSCH{1, 64};
pdschSlot = lastPDSCH_Config.SlotAllocation;
pdschSymbolAlloc = lastPDSCH_Config.SymbolAllocation;
pdschStartSymbolInSlot = pdschSymbolAlloc(1);
pdschDuration = pdschSymbolAlloc(2);
EndSymbol = pdschSlot * symbolsPerSlot + pdschStartSymbolInSlot + pdschDuration;

freqRange = 1:size(bwpGrid, 1);
timeRange = StartSymbol:EndSymbol;

CroppedGrid = bwpGrid(freqRange, timeRange);

numPDSCHInstances = 64;
gridWithSensing = CroppedGrid;
bwpNRB = wavegenConfig.BandwidthParts{1, 1}.NSizeBWP;
numSubcarriers = size(CroppedGrid, 1);

% Choose the sensing-pilot frequency pattern.
switch pilotStrategy
    case 'None'
        sparse_relative_positions = [];

    case 'Sparse'
        if bwpNRB == 24
            sparse_relative_positions = generate_UF4BL(30) + 1;
        elseif bwpNRB == 48
            sparse_relative_positions = generate_ANAII_2(42) + 1;
        else
            sparse_relative_positions = 1:4:numSubcarriers;
        end

    case 'Coprime'
        sparse_relative_positions = generate_Coprime(numSubcarriers);

    case 'Full'
        sparse_relative_positions = 1:numSubcarriers;

    otherwise
        error('Cal_SensingGrid:UnknownPilotStrategy', ...
            'Unsupported pilot strategy "%s".', pilotStrategy);
end


% Fill candidate sensing REs, then clear REs already used by PDSCH.
for i = 1:numPDSCHInstances
    pdschConfig = wavegenConfig.PDSCH{i};
    pdschPRBSet = pdschConfig.PRBSet;
    pdschCarrierIndex = 1:(pdschPRBSet(end)+1)*12;
    pdschSlot = pdschConfig.SlotAllocation;
    pdschSymbolAlloc = pdschConfig.SymbolAllocation;
    pdschStartSymbolInSlot = pdschSymbolAlloc(1);
    pdschDuration = pdschSymbolAlloc(2);
    pdschStartTime = pdschSlot * symbolsPerSlot + pdschStartSymbolInSlot + 1;
    pdschEndTime = pdschStartTime + pdschDuration - 1;

    pdschTimeRangeInCropped = (pdschStartTime:pdschEndTime) - StartSymbol + 1;

    if ~isempty(sparse_relative_positions)
        sensingFreqRange = sparse_relative_positions;

        numSparseSymbols = numel(sensingFreqRange);
        randomBits = randi([0 1], numSparseSymbols * 2, 1);
        sparseSensingSignal = nrSymbolModulate(randomBits, 'QPSK');

        sensingGrid = complex(zeros(size(CroppedGrid)));
        for symIdx = pdschTimeRangeInCropped
            sensingGrid(sensingFreqRange, symIdx) = sparseSensingSignal;
        end

        sensingGrid(pdschCarrierIndex, pdschTimeRangeInCropped) = 0;

        gridWithSensing = gridWithSensing + sensingGrid;
    end
end

sensingGrid_full = bwpGrid;
sensingGrid_full(freqRange, timeRange) = gridWithSensing;

mask = (gridWithSensing ~= 0);
commMask = (CroppedGrid ~= 0);
sensingMask = mask & ~commMask;

stats = struct();
stats.PilotStrategy = pilotStrategy;
stats.CommMask = commMask;
stats.SensingMask = sensingMask;
stats.NumCommRE = nnz(commMask);
stats.NumSensingRE = nnz(sensingMask);
stats.RawCommEnergy = sum(abs(CroppedGrid(commMask)).^2);
stats.RawSensingEnergy = sum(abs(gridWithSensing(sensingMask)).^2);
stats.RawTotalEnergy = sum(abs(gridWithSensing(:)).^2);
stats.SymbolCount = size(gridWithSensing, 2);

end
