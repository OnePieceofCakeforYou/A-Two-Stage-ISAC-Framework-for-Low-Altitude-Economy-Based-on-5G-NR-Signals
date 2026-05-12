

function wavegenConfig = hSIB1WaveformConfiguration(config)

    wavegenConfig = nrDLCarrierConfig;
    wavegenConfig.NCellID = config.NCellID;

    ssBurst = getWavegenSSBurstConfig(config);
    transmittedBlocks = ssBurst.TransmittedBlocks;

    [commonCarrier,commonBwp] = getCommonSCSCarrierAndBWPConfig(ssBurst,config.MinChannelBW);

    carriers{1} = commonCarrier;
    scsSSB = hSSBurstSubcarrierSpacing(ssBurst.BlockPattern);
    scsCommon = ssBurst.SubcarrierSpacingCommon;
    if scsSSB ~= scsCommon
        ssbCarrier = nrSCSCarrierConfig;
        ssbCarrier.NSizeGrid = commonCarrier.NSizeGrid*scsCommon/scsSSB;
        ssbCarrier.SubcarrierSpacing = scsSSB;
        carriers{2} = ssbCarrier;
    end

    bwps{1} = commonBwp;

    msbIdx = floor(ssBurst.PDCCHConfigSIB1/16);
    scsPair = [scsSSB scsCommon];
    kssb = ssBurst.KSSB;
    [csetNRB,csetDuration,~,csetPattern] = hCORESET0Resources(msbIdx,scsPair,config.MinChannelBW,kssb);

    coreset = nrCORESETConfig();
    coreset.FrequencyResources = ones(1,csetNRB/6);
    coreset.Duration = csetDuration;

    coreset.CCEREGMapping = 'interleaved';
    coreset.REGBundleSize = 6;
    coreset.InterleaverSize = 2;
    coreset.ShiftIndex = config.NCellID;
    coreset.CORESETID = 0;

    ss = getType0CommonSearchSpaces(ssBurst,csetNRB,csetDuration,csetPattern);

    dci = DCIFormat1_0_SIRNTI(csetNRB);
    dci.FrequencyDomainResources = hRIV(csetNRB,0,8);
    dci.TimeDomainResources = 0;
    dci.VRBToPRBMapping = 0;
    dci.ModulationCoding = 0;
    dci.RedundancyVersion = 0;
    dci.SystemInformationIndicator = 0;
    dci.ReservedBits = 0;

    numSS = numel(ss);
    dci = repmat(dci,1,numSS);

    if isfield(config,'DCI')
        dci = copyFields(config.DCI,dci);
    end

    enabledPDCCH = transmittedBlocks & config.EnableSIB1;
    pdcch = getWavegenPDCCHConfig(ss,dci,enabledPDCCH);

    ssSlotPeriod = vertcat(ss(:).SlotPeriodAndOffset);
    enablePDSCH = transmittedBlocks & config.EnableSIB1;
    pdsch = getWavegenPDSCHConfig(csetNRB,csetPattern,ssBurst.DMRSTypeAPosition,dci,ssSlotPeriod,enablePDSCH);

    numSubframes = 20;
    if any(scsSSB == [15 30])
        FR = 'FR1';
        BW = 100;
    else
        FR = 'FR2';
        BW = 400;
        if csetPattern == 1
            numSubframes = 25;
        end
    end

    wavegenConfig.SCSCarriers = carriers;
    wavegenConfig.BandwidthParts = bwps;
    wavegenConfig.SSBurst = ssBurst;
    wavegenConfig.CORESET = {coreset};
    wavegenConfig.SearchSpaces = mat2cell(ss(:),ones(1,length(ss)))';
    wavegenConfig.PDCCH = mat2cell(pdcch(:),ones(1,length(pdcch)))';
    wavegenConfig.PDSCH = mat2cell(pdsch(:),ones(1,length(pdsch)))';
    wavegenConfig.FrequencyRange = FR;
    wavegenConfig.ChannelBandwidth = BW;
    wavegenConfig.NumSubframes = numSubframes;

    if (~isfield(config,'Power'))
        config.Power = zeros(size(config.TransmittedBlocks));
    end
    wavegenConfig.SSBurst.Power = config.Power + 10*log10(scsCommon/scsSSB);

    L_max = length(config.TransmittedBlocks);
    for i = 1:L_max
        wavegenConfig.PDCCH{i}.Power = config.Power(i);
        wavegenConfig.PDSCH{i}.Power = config.Power(i);
    end

end

function [carrier,bwp] = getCommonSCSCarrierAndBWPConfig(ssb,minChanBW)

    scsCommon = ssb.SubcarrierSpacingCommon;

    carrier = nrSCSCarrierConfig;
    carrier.SubcarrierSpacing = scsCommon;
    carrier.NStartGrid = 0;

    msbIdx = floor(ssb.PDCCHConfigSIB1/16);
    scsSSB = hSSBurstSubcarrierSpacing(ssb.BlockPattern);
    scs = [scsSSB scsCommon];
    kssb = ssb.KSSB;
    [csetNRB,~,csetFreqOffset,~,csetTable] = hCORESET0Resources(msbIdx,scs,minChanBW,kssb);

    if isnan(csetNRB)
        idx = max(csetTable(~isnan(csetTable(:,2)),1));
        error('hSIB1WaveformConfiguration: For this SSB block pattern, common subcarrier spacing and minimum channel bandwidth, PDCCHConfigSIB1 must be lower than %d.', idx*16-1)
    end

    c0 = (csetFreqOffset+10*scsSSB/scsCommon);
    carrier.NSizeGrid = 2*max(c0,csetNRB-c0);

    bwp = nrWavegenBWPConfig('BandwidthPartID',1,'Label','COMMON');
    bwp.SubcarrierSpacing = carrier.SubcarrierSpacing;
    bwp.NSizeBWP = csetNRB;
    bwp.NStartBWP = carrier.NStartGrid + carrier.NSizeGrid/2 - c0;

end

function ssBurst = getWavegenSSBurstConfig(ssb)

    ssBurst = nrWavegenSSBurstConfig;
    ssBurst.BlockPattern = ssb.BlockPattern;
    ssBurst.TransmittedBlocks = ssb.TransmittedBlocks;

    ssBurst.SubcarrierSpacingCommon = ssb.SubcarrierSpacingCommon;

    if isfield(ssb,'DMRSTypeAPosition')
        ssBurst.DMRSTypeAPosition = ssb.DMRSTypeAPosition;
    else
        ssBurst.DMRSTypeAPosition = 3;
    end

    if isfield(ssb,'PDCCHConfigSIB1')
        ssBurst.PDCCHConfigSIB1 = ssb.PDCCHConfigSIB1;
    else
        ssBurst.PDCCHConfigSIB1 = 0*16+4;
    end

    if isfield(ssb,'Period')
        ssBurst.Period = ssb.Period;
    elseif ssBurst.SubcarrierSpacingCommon < 60
        ssBurst.Period = 20;
    else
        ssBurst.Period = 40;
    end

end

function SS = getType0CommonSearchSpaces(ssb,csetNRB,csetDuration,csetPattern)

    ssbTransmittedBlocks = ssb.TransmittedBlocks;
    L_max = length(ssbTransmittedBlocks);
    scs = [hSSBurstSubcarrierSpacing(ssb.BlockPattern) ssb.SubcarrierSpacingCommon];
    lsbIdx = mod(ssb.PDCCHConfigSIB1,16);
    maxAL = floor(log2(csetNRB*csetDuration/6))+1;
    slotsPerFrame = 10*scs(2)/15;

    framePeriod = ssb.Period/10;

    SS(1:L_max) = nrSearchSpaceConfig();
    ssID = 1;
    for ssbIdx = 0:L_max-1
        [ssSlot,ssFirstSym,~,frameOffset] = hPDCCH0MonitoringOccasions(lsbIdx,ssbIdx,scs,csetPattern,csetDuration);

        ss = nrSearchSpaceConfig();
        ss.CORESETID = 0;
        ss.SearchSpaceType = 'Common';
        ss.StartSymbolWithinSlot = ssFirstSym;

        period = framePeriod*slotsPerFrame;
        offset = mod(ssSlot + frameOffset*slotsPerFrame,period);
        ss.SlotPeriodAndOffset = [period offset];

        if csetPattern==1
            ss.Duration = 2;
        else
            ss.Duration = 1;
        end
        ss.NumCandidates = [0 0 4 2 1];
        ss.NumCandidates(maxAL+1:end) = 0;
        ss.SearchSpaceID = ssID;
        SS(ssID) = ss;
        ssID = ssID+1;
    end
end

function pdcch = getWavegenPDCCHConfig(ss,dci,enable)

    if length(dci) ~= length(ss)
        error('hSIB1WaveformConfiguration: The length of the DCI structure array must be equal to that of the search space configuration array.');
    end

    pdcch(1:length(ss)) = nrWavegenPDCCHConfig;

    for ch = 1:length(dci)
        dcibits = toBits(dci(ch));

        pdcch(ch).SearchSpaceID = ss(ch).SearchSpaceID;
        pdcch(ch).RNTI = 65535;
        pdcch(ch).DataSource = dcibits;
        pdcch(ch).DataBlockSize = dci.Width;
        pdcch(ch).DMRSScramblingID = [];

        pdcch(ch).Period = ss(ch).SlotPeriodAndOffset(1);
        pdcch(ch).SlotAllocation = ss(ch).SlotPeriodAndOffset(2);

        pdcch(ch).AggregationLevel = 2^(find(ss(ch).NumCandidates,1,'last')-1);
        pdcch(ch).AllocatedCandidate = 1;

        pdcch(ch).Enable = enable(ch);
    end

end

function pdsch = getWavegenPDSCHConfig(csetNRB,csetPattern,dmrsTypeAPosition,dci,ssSlotPeriod,enable)

    nch = length(dci);
    pdsch(1:nch) = nrWavegenPDSCHConfig;
    for ch = 1:nch

        [pdschTmp,K_0] = hSIB1PDSCHConfiguration(dci(ch),csetNRB,dmrsTypeAPosition,csetPattern);

        pdsch(ch).RNTI = pdschTmp.RNTI;
        pdsch(ch).ReservedPRB = pdschTmp.ReservedPRB;
        pdsch(ch).Modulation = pdschTmp.Modulation;
        pdsch(ch).NumLayers = pdschTmp.NumLayers;
        pdsch(ch).MappingType = pdschTmp.MappingType;
        pdsch(ch).SymbolAllocation = pdschTmp.SymbolAllocation;
        pdsch(ch).PRBSetType = pdschTmp.PRBSetType;
        pdsch(ch).PRBSet = pdschTmp.PRBSet;
        pdsch(ch).VRBToPRBInterleaving = pdschTmp.VRBToPRBInterleaving;
        pdsch(ch).NID = pdschTmp.NID;
        pdsch(ch).RNTI = pdschTmp.RNTI;
        pdsch(ch).DMRS = pdschTmp.DMRS;
        pdsch(ch).EnablePTRS = pdschTmp.EnablePTRS;

        pdsch(ch).Period = ssSlotPeriod(ch,1);
        pdsch(ch).SlotAllocation = ssSlotPeriod(ch,2) + K_0;
        mcsTables = nrPDSCHMCSTables;
        qam64Table = mcsTables.QAM64Table;
        pdsch(ch).TargetCodeRate = qam64Table.TargetCodeRate(qam64Table.MCSIndex==dci(ch).ModulationCoding);
        pdsch(ch).XOverhead = 0;
        pdsch(ch).RVSequence = dci(ch).RedundancyVersion;
        pdsch(ch).Enable = enable(ch);

    end

end

function RIV = hRIV(NSizeBWP,RBStart,LRBS)

    if LRBS<1 || LRBS>(NSizeBWP-RBStart)
        error('The PDSCH allocation is out of the BWP limits.');
    end

    if (LRBS-1) <= floor(NSizeBWP/2)
        RIV = NSizeBWP*(LRBS-1)+RBStart;
    else
        RIV = NSizeBWP*(NSizeBWP-LRBS+1) + (NSizeBWP-1-RBStart);
    end

end

function dest = copyFields(source,dest)

    nd = numel(dest);
    if numel(source) == 1
        source = repmat(source, 1, nd);
    end

    sFields = fields(source(1));
    for e = 1:nd
        for idf = 1:numel(sFields)
            thisField = sFields{idf};
            dest(e).(thisField) = source(e).(thisField);
        end
    end

end
