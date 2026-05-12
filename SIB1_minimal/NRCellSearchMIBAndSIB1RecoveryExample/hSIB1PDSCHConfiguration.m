

function [pdsch,K_0] = hSIB1PDSCHConfiguration(dci,NSizeBWP,DMRSTypeAPosition,pat)

    pdsch = nrPDSCHConfig();
    pdsch.NSizeBWP = [];
    pdsch.NStartBWP = [];

    pdsch.RNTI = 65535;

    pdsch.VRBToPRBInterleaving = dci.VRBToPRBMapping;
    pdsch.PRBSetType = 'VRB';
    [Lrbs,RBstart] = hDecodeRIV(NSizeBWP,dci.FrequencyDomainResources);
    pdsch.PRBSet = RBstart + (0:(Lrbs-1));

    restables = hPDSCHTimeAllocationTables();
    restable = restables{pat};
    restable = restable(restable.rowIndex==(dci.TimeDomainResources+1),:);
    resalloc = restable(restable.DMRSTypeAPosition==DMRSTypeAPosition,:);

    K_0 = resalloc.K_0;

    pdsch.MappingType = resalloc.PDSCHMappingType;
    pdsch.SymbolAllocation = [resalloc.S resalloc.L];

    pdsch.NID = [];
    pdsch.DMRS.DMRSTypeAPosition = DMRSTypeAPosition;
    pdsch.DMRS.NIDNSCID = [];

    pdsch.Modulation = 'QPSK';
    pdsch.DMRS.NSCID = 0;
    pdsch.NumLayers = 1;
    pdsch.DMRS.DMRSPortSet = 0;
    pdsch.DMRS.DMRSConfigurationType = 1;
    pdsch.DMRS.DMRSLength = 1;
    L = pdsch.SymbolAllocation(2);
    if (L==2)
        pdsch.DMRS.NumCDMGroupsWithoutData = 1;
    else
        pdsch.DMRS.NumCDMGroupsWithoutData = 2;
    end
    if (strcmpi(pdsch.MappingType,'A'))
        pdsch.DMRS.DMRSAdditionalPosition = 2;
    else
        switch L
            case {2,4}
                pdsch.DMRS.DMRSAdditionalPosition = 0;
            case 7
                pdsch.DMRS.DMRSAdditionalPosition = 1;
        end
    end

    pdsch.DMRS.DMRSReferencePoint = 'PRB0';

    pdsch.EnablePTRS = false;

end

function [Lrbs,RBstart] = hDecodeRIV(NSizeBWP,RIV)

    Lrbs = floor(RIV / NSizeBWP) + 1;

    RBstart = RIV - ((Lrbs - 1) * NSizeBWP);

    if (Lrbs > NSizeBWP - RBstart)

        Lrbs = NSizeBWP - Lrbs + 2;
        RBstart = NSizeBWP - 1 - RBstart;

    end

end
