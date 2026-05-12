function results = RecoverSIB1FromWaveform(rxWaveform, rxConfig)

% Receiver chain: synchronize on SSB, decode BCH/DCI, then decode SIB1.
arguments
    rxWaveform (:,1) {mustBeNumeric}
    rxConfig struct
end

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'NRCellSearchMIBAndSIB1RecoveryExample'));

results = initResults();

sampleRate = rxConfig.SampleRate;
fPhaseComp = rxConfig.FPhaseComp;
minChannelBW = rxConfig.MinChannelBW;
refBurst = rxConfig.RefBurst;
normalizeRxGrid = false;
if isfield(rxConfig, 'NormalizeRxGrid')
    normalizeRxGrid = logical(rxConfig.NormalizeRxGrid);
end

try
    % SSB search and coarse synchronization.
    nrbSSB = 20;
    scsSSB = hSSBurstSubcarrierSpacing(refBurst.BlockPattern);
    rxOfdmInfo = nrOFDMInfo(nrbSSB, scsSSB, 'SampleRate', sampleRate);

    searchBW = 6 * scsSSB;
    [rxWave, freqOffset, NID2] = hSSBurstFrequencyCorrect( ...
        rxWaveform, refBurst.BlockPattern, sampleRate, searchBW, false);
    results.FreqOffset_Hz = freqOffset;
    results.NID2 = NID2;

    refGrid = zeros([nrbSSB * 12 2]);
    refGrid(nrPSSIndices, 2) = nrPSS(NID2);

    nSlot = 0;
    timingOffset = nrTimingEstimate( ...
        rxWave, nrbSSB, scsSSB, nSlot, refGrid, 'SampleRate', sampleRate);
    results.TimingOffset = timingOffset;

    rxGrid = nrOFDMDemodulate( ...
        rxWave(1 + timingOffset:end, :), nrbSSB, scsSSB, nSlot, ...
        'SampleRate', sampleRate);
    rxGrid = rxGrid(:, 2:5, :);

    sssIndices = nrSSSIndices;
    sssRx = nrExtractResources(sssIndices, rxGrid);

    sssEst = zeros(1, 336);
    for NID1 = 0:335
        ncellidTmp = (3 * NID1) + NID2;
        sssRef = nrSSS(ncellidTmp);
        sssEst(NID1 + 1) = sum(abs(mean(sssRx .* conj(sssRef), 1)).^2);
    end

    NID1 = find(sssEst == max(sssEst), 1, 'first') - 1;
    ncellid = (3 * NID1) + NID2;
    results.NCellID = ncellid;

    dmrsIndices = nrPBCHDMRSIndices(ncellid);
    dmrsEst = zeros(1, 8);
    for ibarSSB = 0:7
        refGrid = zeros([240 4]);
        refGrid(dmrsIndices) = nrPBCHDMRS(ncellid, ibarSSB);
        [hestTmp, nestTmp] = nrChannelEstimate( ...
            rxGrid, refGrid, 'AveragingWindow', [0 1]);
        dmrsEst(ibarSSB + 1) = 10 * log10(mean(abs(hestTmp(:)).^2) / nestTmp);
    end

    ibarSSB = find(dmrsEst == max(dmrsEst), 1, 'first') - 1;
    results.PBCHDMRSSNR_dB = max(dmrsEst);

    refGrid = zeros([nrbSSB * 12 4]);
    refGrid(dmrsIndices) = nrPBCHDMRS(ncellid, ibarSSB);
    refGrid(sssIndices) = nrSSS(ncellid);
    [hest, nVar] = nrChannelEstimate(rxGrid, refGrid, 'AveragingWindow', [0 1]);

    [pbchIndices, pbchIndicesInfo] = nrPBCHIndices(ncellid);
    pbchRx = nrExtractResources(pbchIndices, rxGrid);

    if refBurst.L_max == 4
        v = mod(ibarSSB, 4);
    else
        v = ibarSSB;
    end
    ssbIndex = v;

    pbchHest = nrExtractResources(pbchIndices, hest);
    [pbchEq, csi] = nrEqualizeMMSE(pbchRx, pbchHest, nVar);
    Qm = pbchIndicesInfo.G / pbchIndicesInfo.Gd;
    csi = repmat(csi.', Qm, 1);
    csi = reshape(csi, [], 1);

    pbchBits = nrPBCHDecode(pbchEq, ncellid, v, nVar);
    pbchBits = pbchBits .* csi;

    polarListLength = 8;
    [~, crcBCH, trblk, sfn4lsb, nHalfFrame, msbidxoffset] = ...
        nrBCHDecode(pbchBits, polarListLength, refBurst.L_max, ncellid);

    results.BCHCRC = crcBCH;
    results.BCHSuccess = (crcBCH == 0);
    if ~results.BCHSuccess
        results.FailureStage = "BCH";
        return;
    end

    if refBurst.L_max == 64
        ssbIndex = ssbIndex + (bit2int(msbidxoffset, 3) * 8);
        kSSB = 0;
    else
        kSSB = msbidxoffset * 16;
    end
    results.SSBIndex = ssbIndex;

    mib = fromBits(MIB, trblk(2:end));
    initialSystemInfo = initSystemInfoLocal(mib, sfn4lsb, kSSB, refBurst.L_max);

    if ~isCORESET0PresentLocal(refBurst.BlockPattern, initialSystemInfo.k_SSB)
        results.FailureStage = "CORESET0Absent";
        return;
    end

    scsCommon = initialSystemInfo.SubcarrierSpacingCommon;
    scsKSSB = kSSBSubcarrierSpacingLocal(scsCommon);
    kFreqShift = initialSystemInfo.k_SSB * scsKSSB * 1e3;
    rxWave = rxWave .* exp(1i * 2 * pi * kFreqShift * (0:length(rxWave) - 1)' / sampleRate);
    fPhaseComp = fPhaseComp - kFreqShift;

    [frameOffset, nLeadingFrames] = hTimingOffsetToFirstFrameLocal( ...
        timingOffset, refBurst, ssbIndex, nHalfFrame, sampleRate);

    zeroPadding = zeros(-min(frameOffset, 0), size(rxWave, 2));
    rxWave = [zeroPadding; rxWave(1 + max(frameOffset, 0):end, :)];

    nrb = hCORESET0DemodulationBandwidthLocal(initialSystemInfo, scsSSB, minChannelBW);
    if sampleRate < nrb * 12 * scsCommon * 1e3
        results.FailureStage = "InsufficientSampleRate";
        return;
    end

    nSlot = 0;
    rxGrid = nrOFDMDemodulate( ...
        rxWave, nrb, scsCommon, nSlot, ...
        'SampleRate', sampleRate, 'CarrierFrequency', fPhaseComp);

    initialSystemInfo.NFrame = mod(initialSystemInfo.NFrame - nLeadingFrames, 1024);
    numRxSym = size(rxGrid, 2);
    [csetSubcarriers, monSlots, monSlotsSym] = hPDCCH0MonitoringResourcesLocal( ...
        initialSystemInfo, scsSSB, minChannelBW, ssbIndex, numRxSym);

    if isempty(monSlotsSym)
        results.FailureStage = "NoPDCCHMonitoringOccasion";
        return;
    end

    rxMonSlotGrid = rxGrid(csetSubcarriers, monSlotsSym, :);

    scsPair = [scsSSB scsCommon];
    [pdcch, csetPattern] = hPDCCH0Configuration( ...
        ssbIndex, initialSystemInfo, scsPair, ncellid, minChannelBW);
    carrier = hCarrierConfigSIB1Local(ncellid, initialSystemInfo, pdcch);

    % Blind-search Type0 PDCCH candidates for the SI-RNTI DCI.
    dci = DCIFormat1_0_SIRNTI(pdcch.NSizeBWP);
    symbolsPerSlot = 14;
    siRNTI = 65535;
    dciCRC = true;
    dcibits = [];
    mSlotIdx = 0;

    while (mSlotIdx < length(monSlots)) && dciCRC
        carrier.NSlot = monSlots(mSlotIdx + 1);
        [pdcchInd, pdcchDmrsSym, pdcchDmrsInd] = nrPDCCHSpace(carrier, pdcch);

        rxSlotGrid = rxMonSlotGrid(:, (1:symbolsPerSlot) + symbolsPerSlot * mSlotIdx, :);
        if normalizeRxGrid
            rxSlotGrid = normalizeGridLocal(rxSlotGrid);
        end

        notZero = any(cellfun(@(x) any(rxSlotGrid(x), 'all'), pdcchInd));
        aLevIdx = 1;
        while (aLevIdx <= 5) && dciCRC && notZero
            cIdx = 1;
            numCandidatesAL = pdcch.SearchSpace.NumCandidates(aLevIdx);
            while (cIdx <= numCandidatesAL) && dciCRC
                [hest, nVar] = nrChannelEstimate( ...
                    rxSlotGrid, pdcchDmrsInd{aLevIdx}(:, cIdx), pdcchDmrsSym{aLevIdx}(:, cIdx));

                [pdcchRxSym, pdcchHest] = nrExtractResources( ...
                    pdcchInd{aLevIdx}(:, cIdx), rxSlotGrid, hest);
                pdcchEqSym = nrEqualizeMMSE(pdcchRxSym, pdcchHest, nVar);
                dcicw = nrPDCCHDecode( ...
                    pdcchEqSym, pdcch.DMRSScramblingID, pdcch.RNTI, nVar);

                [dcibits, dciCRC] = nrDCIDecode( ...
                    dcicw, dci.Width, polarListLength, siRNTI);
                cIdx = cIdx + 1;
            end
            aLevIdx = aLevIdx + 1;
        end
        mSlotIdx = mSlotIdx + 1;
    end

    results.DCICRC = double(dciCRC);
    results.DCISuccess = (dciCRC == 0);
    if ~results.DCISuccess
        results.FailureStage = "DCI";
        return;
    end

    mSlotIdx = mSlotIdx - 1;
    monSlotsSym = monSlotsSym(mSlotIdx * symbolsPerSlot + (1:symbolsPerSlot));

    dci = fromBits(dci, dcibits);
    [pdsch, K0] = hSIB1PDSCHConfiguration( ...
        dci, pdcch.NSizeBWP, initialSystemInfo.DMRSTypeAPosition, csetPattern);

    % Decode the PDSCH transport block carrying SIB1.
    carrier.NSlot = carrier.NSlot + K0;
    monSlotsSym = monSlotsSym + symbolsPerSlot * K0;

    pdschDmrsIndices = nrPDSCHDMRSIndices(carrier, pdsch);
    pdschDmrsSymbols = nrPDSCHDMRS(carrier, pdsch);

    mu = log2(scsCommon / 15);
    bw = 2^mu * 100;
    freqStep = 2^mu;
    freqSearch = -bw/2:freqStep:bw/2-freqStep;
    [~, fSearchIdx] = sort(abs(freqSearch));
    freqSearch = freqSearch(fSearchIdx);

    sib1CRC = 1;
    for fpc = fPhaseComp + 1e3 * freqSearch
        rxGrid = nrOFDMDemodulate( ...
            rxWave, nrb, scsCommon, 0, ...
            'SampleRate', sampleRate, 'CarrierFrequency', fpc);

        rxSlotGrid = rxGrid(csetSubcarriers, monSlotsSym, :);
        if normalizeRxGrid
            rxSlotGrid = normalizeGridLocal(rxSlotGrid);
        end

        [hest, nVar] = nrChannelEstimate(rxSlotGrid, pdschDmrsIndices, pdschDmrsSymbols);
        [pdschIndices, pdschIndicesInfo] = nrPDSCHIndices(carrier, pdsch);
        [pdschRxSym, pdschHest] = nrExtractResources(pdschIndices, rxSlotGrid, hest);
        pdschEqSym = nrEqualizeMMSE(pdschRxSym, pdschHest, nVar);

        cw = nrPDSCHDecode(carrier, pdsch, pdschEqSym, nVar);

        decodeDLSCH = nrDLSCHDecoder;
        decodeDLSCH.LDPCDecodingAlgorithm = 'Normalized min-sum';
        XohPDSCH = 0;
        mcsTables = nrPDSCHMCSTables;
        qam64Table = mcsTables.QAM64Table;
        tcr = qam64Table.TargetCodeRate(qam64Table.MCSIndex == dci.ModulationCoding);
        NREPerPRB = pdschIndicesInfo.NREPerPRB;
        tbsLength = nrTBS( ...
            pdsch.Modulation, pdsch.NumLayers, length(pdsch.PRBSet), ...
            NREPerPRB, tcr, XohPDSCH);
        decodeDLSCH.TransportBlockLength = tbsLength;
        decodeDLSCH.TargetCodeRate = tcr;

        [~, sib1CRC] = decodeDLSCH( ...
            cw, pdsch.Modulation, pdsch.NumLayers, dci.RedundancyVersion);

        if sib1CRC == 0
            break;
        end
    end

    results.SIB1CRC = sib1CRC;
    results.SIB1Success = (sib1CRC == 0);
    results.Success = results.BCHSuccess && results.DCISuccess && results.SIB1Success;
    if ~results.SIB1Success
        results.FailureStage = "SIB1";
        return;
    end

    results.FailureStage = "None";

catch ME
    results.ErrorIdentifier = string(ME.identifier);
    results.ErrorMessage = string(ME.message);
    if results.FailureStage == ""
        results.FailureStage = "Exception";
    end
end

end

function results = initResults()
results = struct();
results.Success = false;
results.BCHSuccess = false;
results.DCISuccess = false;
results.SIB1Success = false;
results.BCHCRC = NaN;
results.DCICRC = NaN;
results.SIB1CRC = NaN;
results.FreqOffset_Hz = NaN;
results.TimingOffset = NaN;
results.NID2 = NaN;
results.NCellID = NaN;
results.SSBIndex = NaN;
results.PBCHDMRSSNR_dB = NaN;
results.FailureStage = "";
results.ErrorIdentifier = "";
results.ErrorMessage = "";
end

function present = isCORESET0PresentLocal(ssbBlockPattern, kSSB)
switch ssbBlockPattern
    case {'Case A','Case B','Case C'}
        kssbMax = 23;
    case {'Case D','Case E'}
        kssbMax = 11;
    otherwise
        error('Unsupported SSB block pattern "%s".', ssbBlockPattern);
end
present = (kSSB <= kssbMax);
end

function [timingOffset, nLeadingFrames] = hTimingOffsetToFirstFrameLocal(offset, burst, ssbIdx, nHalfFrame, sampleRate)
scs = hSSBurstSubcarrierSpacing(burst.BlockPattern);
ofdmInfo = nrOFDMInfo(1, scs, 'SampleRate', sampleRate);
srRatio = sampleRate / (scs * 1e3 * ofdmInfo.Nfft);
symbolLengths = ofdmInfo.SymbolLengths * srRatio;

offset = offset + symbolLengths(1);

burstStartSymbols = hSSBurstStartSymbols(burst.BlockPattern, burst.L_max);
ssbFirstSym = burstStartSymbols(ssbIdx + 1);

symbolsPerSubframe = length(symbolLengths);
subframeOffset = floor(ssbFirstSym / symbolsPerSubframe);
samplesPerSubframe = sum(symbolLengths);
timingOffset = offset - (subframeOffset * samplesPerSubframe);

symbolOffset = mod(ssbFirstSym, symbolsPerSubframe);
timingOffset = timingOffset - sum(symbolLengths(1:symbolOffset));

timingOffset = timingOffset - nHalfFrame * 5 * samplesPerSubframe;

repetitions = ceil(timingOffset / (20 * samplesPerSubframe));
timingOffset = round(timingOffset - repetitions * 20 * samplesPerSubframe);

nLeadingFrames = 2 * repetitions;
end

function initSystemInfo = initSystemInfoLocal(mib, sfn4lsb, kSSB, Lmax)
if Lmax == 64
    scsCommon = [60 120];
else
    scsCommon = [15 30];
end

initSystemInfo = struct();
initSystemInfo.NFrame = mib.systemFrameNumber * 2^4 + bit2int(sfn4lsb, 4);
initSystemInfo.SubcarrierSpacingCommon = scsCommon(mib.subCarrierSpacingCommon + 1);
initSystemInfo.k_SSB = kSSB + mib.ssb_SubcarrierOffset;
initSystemInfo.DMRSTypeAPosition = 2 + mib.dmrs_TypeA_Position;
initSystemInfo.PDCCHConfigSIB1 = info(mib.pdcch_ConfigSIB1);
initSystemInfo.CellBarred = mib.cellBarred;
initSystemInfo.IntraFreqReselection = mib.intraFreqReselection;
end

function nrb = hCORESET0DemodulationBandwidthLocal(sysInfo, scsSSB, minChannelBW)
cset0Idx = sysInfo.PDCCHConfigSIB1.controlResourceSetZero;
scsCommon = sysInfo.SubcarrierSpacingCommon;
scsPair = [scsSSB scsCommon];
[csetNRB, ~, csetFreqOffset] = hCORESET0Resources(cset0Idx, scsPair, minChannelBW, sysInfo.k_SSB);
c0 = csetFreqOffset + 10 * scsSSB / scsCommon;
nrb = 2 * max(c0, csetNRB - c0) + 2;
end

function [k, slots, slotSymbols] = hPDCCH0MonitoringResourcesLocal(systemInfo, scsSSB, minChannelBW, ssbIndex, numRxSym)
cset0Idx = systemInfo.PDCCHConfigSIB1.controlResourceSetZero;
scsCommon = systemInfo.SubcarrierSpacingCommon;
scsPair = [scsSSB scsCommon];
kSSB = systemInfo.k_SSB;
[c0NRB, c0Duration, c0FreqOffset, c0Pattern] = hCORESET0Resources(cset0Idx, scsPair, minChannelBW, kSSB);

ssIdx = systemInfo.PDCCHConfigSIB1.searchSpaceZero;
[ssSlot, ~, isOccasion] = hPDCCH0MonitoringOccasions(ssIdx, ssbIndex, scsPair, c0Pattern, c0Duration, systemInfo.NFrame);

slotsPerFrame = 10 * scsCommon / 15;
ssSlot = ssSlot + (~isOccasion) * slotsPerFrame;

monSlotsPerPeriod = 1 + (c0Pattern == 1);

nrb = hCORESET0DemodulationBandwidthLocal(systemInfo, scsSSB, minChannelBW);
k = 12 * (nrb - 20 * scsSSB / scsCommon) / 2 - c0FreqOffset * 12 + (1:c0NRB * 12);

symbolsPerSlot = 14;
numRxSlots = ceil(numRxSym / symbolsPerSlot);
slots = ssSlot + (0:monSlotsPerPeriod-1)' + (0:2*slotsPerFrame:(numRxSlots-ssSlot-1));
slots = slots(:).';
slotSymbols = slots * symbolsPerSlot + (1:symbolsPerSlot)';
slotSymbols = slotSymbols(:).';
slotSymbols(slotSymbols > numRxSym) = [];
slots = (slotSymbols(1:symbolsPerSlot:end) - 1) / symbolsPerSlot;
end

function scsKSSB = kSSBSubcarrierSpacingLocal(scsCommon)
if scsCommon > 30
    scsKSSB = scsCommon;
else
    scsKSSB = 15;
end
end

function carrier = hCarrierConfigSIB1Local(ncellid, initSystemInfo, pdcch)
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = initSystemInfo.SubcarrierSpacingCommon;
carrier.NStartGrid = pdcch.NStartBWP;
carrier.NSizeGrid = pdcch.NSizeBWP;
carrier.NSlot = pdcch.SearchSpace.SlotPeriodAndOffset(2);
carrier.NFrame = initSystemInfo.NFrame;
carrier.NCellID = ncellid;
end

function grid = normalizeGridLocal(grid)
scale = max(abs(grid(:)));
if scale > 0
    grid = grid / scale;
end
end
