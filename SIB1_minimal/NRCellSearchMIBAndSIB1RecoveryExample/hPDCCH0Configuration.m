

function [pdcch,csetPattern] = hPDCCH0Configuration(ssbIndex,initSystemInfo,scs,ncellid,minChanBW)

    slotsPerFrame = 10*initSystemInfo.SubcarrierSpacingCommon/15;

    msbIdx = initSystemInfo.PDCCHConfigSIB1.controlResourceSetZero;
    kssb = initSystemInfo.k_SSB;
    [csetNRB,csetDuration,~,csetPattern] = hCORESET0Resources(msbIdx,scs,minChanBW,kssb);

    coreset = nrCORESETConfig();
    coreset.FrequencyResources = ones(1,csetNRB/6);
    coreset.Duration = csetDuration;
    coreset.CCEREGMapping = 'interleaved';
    coreset.REGBundleSize = 6;
    coreset.InterleaverSize = 2;
    coreset.ShiftIndex = ncellid;
    coreset.CORESETID = 0;

    lsbIdx = initSystemInfo.PDCCHConfigSIB1.searchSpaceZero;
    [ssSlot,ssFirstSym,isOccasion] = hPDCCH0MonitoringOccasions(lsbIdx,ssbIndex,scs,csetPattern,csetDuration,initSystemInfo.NFrame);
    ssSlot = ssSlot + (~isOccasion)*slotsPerFrame + mod(initSystemInfo.NFrame,2)*slotsPerFrame;

    ss = nrSearchSpaceConfig();
    ss.CORESETID = coreset.CORESETID;
    ss.SearchSpaceType = 'Common';
    ss.StartSymbolWithinSlot = ssFirstSym;
    ss.Duration = 1 + (csetPattern == 1);

    slotPeriod = 2*slotsPerFrame;
    slotOffset = mod(ssSlot,slotPeriod);
    ss.SlotPeriodAndOffset = [slotPeriod slotOffset];
    ss.NumCandidates = [0 0 4 2 1];

    maxAL = floor(log2(csetNRB*csetDuration/6))+1;
    ss.NumCandidates(maxAL+1:end) = 0;

    pdcch = nrPDCCHConfig();
    pdcch.NStartBWP = 0;
    pdcch.NSizeBWP = csetNRB;
    pdcch.CORESET = coreset;
    pdcch.SearchSpace = ss;
    pdcch.RNTI = 0;
    pdcch.DMRSScramblingID = ncellid;

end
