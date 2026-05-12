function  [info,grid]= cal_SSBburst(SSBburst,ncellid)






info = nr5g.internal.wavegen.hSSBurstInfo(SSBburst);
coder.noImplicitExpansionInFunction;


NRB = info.NRB;
burstSCS = info.SubcarrierSpacing;
burstCP = info.CyclicPrefix;
c = nrCarrierConfig('SubcarrierSpacing', burstSCS, ...
    'NSizeGrid', NRB, ...
    'CyclicPrefix', burstCP);

grid = repmat(nrResourceGrid(c), 1, c.SlotsPerSubframe*5);

for i = 1:numel(info.SSBIndex)

    SSBIndex = info.SSBIndex(i);
    i_SSB = info.i_SSB(i);
    ibar_SSB = info.ibar_SSB(i);

    ssbGrid = complex(zeros([240 4 1]));

    pss = nrPSS(ncellid);
    pssInd = nrPSSIndices();
    ssbGrid(pssInd) = pss;

    sss = nrSSS(ncellid);
    sssInd = nrSSSIndices();
    ssbGrid(sssInd) = sss;

    pbchDmrs = nrPBCHDMRS(ncellid,ibar_SSB);
    pbchDmrsInd = nrPBCHDMRSIndices(ncellid);
    ssbGrid(pbchDmrsInd) = pbchDmrs;

    if (info.L==64)
        idxoffset = SSBIndex;
    else
        idxoffset = info.k_SSB;
    end
    cw = nrBCH(info.MIB(1:24, 1), fix(SSBburst.NFrame),SSBburst.NHalfFrame,info.L,idxoffset,ncellid);

    v = i_SSB;
    pbch = nrPBCH(cw,ncellid,v);
    pbchInd = nrPBCHIndices(ncellid);
    ssbGrid(pbchInd) = pbch;

    ssbGrid = ssbGrid * db2mag(SSBburst.Power(mod(SSBIndex,length(SSBburst.Power))+1));
    occupiedSymbols = info.OccupiedSymbols(i,:);
    grid(info.OccupiedSubcarriers,occupiedSymbols,:) = ssbGrid;
end

end
