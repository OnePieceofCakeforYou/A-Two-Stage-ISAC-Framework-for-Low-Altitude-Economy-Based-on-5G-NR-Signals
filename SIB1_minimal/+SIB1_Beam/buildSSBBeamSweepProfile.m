function beamProfile = buildSSBBeamSweepProfile(sim, config, meta, userAzimuth_deg)

% Convert swept transmit beams into a sample-wise gain profile.
c = physconst('LightSpeed');
lambda = c / sim.CenterFrequency_Hz;

txArray = phased.NRRectangularPanelArray( ...
    'Size', [sim.NumTransmitAntennas 1 1 1], ...
    'Spacing', [0.5 * lambda 0.5 * lambda 1 1], ...
    'ElementSet', {phased.IsotropicAntennaElement});
steervecTx = phased.SteeringVector( ...
    'SensorArray', txArray, 'PropagationSpeed', c);

azBW = beamwidth(txArray, sim.CenterFrequency_Hz, 'Cut', 'Azimuth');
elBW = beamwidth(txArray, sim.CenterFrequency_Hz, 'Cut', 'Elevation');

numSSB = numel(config.TransmittedBlocks);
numPhysicalBeams = ceil(numSSB / 2);
beamAngles_deg = hGetBeamSweepAngles( ...
    numPhysicalBeams, sim.TxAzSweep_deg, sim.TxElSweep_deg, ...
    azBW, elBW, sim.ElevationSweep);

bsToUe = [sim.Distance_m; 0; sim.UEHeight_m - sim.BSHeight_m];
[azUser, elUser, ~] = cart2sph(bsToUe(1), bsToUe(2), bsToUe(3));
if nargin < 4 || isempty(userAzimuth_deg)
    userAngle_deg = [rad2deg(azUser); rad2deg(elUser)];
else
    userAngle_deg = [userAzimuth_deg; rad2deg(elUser)];
end

userSteering = steervecTx(sim.CenterFrequency_Hz, userAngle_deg);
beamGainLinear = zeros(numPhysicalBeams, 1);
for beamIdx = 1:numPhysicalBeams
    beamSteering = steervecTx(sim.CenterFrequency_Hz, beamAngles_deg(:, beamIdx));

    beamWeight = beamSteering / sqrt(sim.NumTransmitAntennas);
    beamGainLinear(beamIdx) = abs(userSteering' * beamWeight)^2;
end
beamGainLinear = max(real(beamGainLinear), 1e-8);

ssbGainLinear = repelem(beamGainLinear, 2);
ssbGainLinear = ssbGainLinear(1:numSSB);

% Associate SSB and RMSI symbols with each physical beam pair.
wavegenConfig = meta.WavegenConfig;
ssburst = nr5g.internal.wavegen.mapSSBObj2Struct( ...
    wavegenConfig.SSBurst, wavegenConfig.SCSCarriers);
[ssbInfo, ~] = cal_SSBburst(ssburst, wavegenConfig.NCellID);

numSymbols = numel(meta.SymbolLengthsAll);
symbolGainLinear = ones(1, numSymbols);
assignedActiveSymbols = false(1, numSymbols);
symbolsPerSlot = 14;

for beamIdx = 1:numPhysicalBeams
    gainLinear = beamGainLinear(beamIdx);
    ssbIdx1 = 2 * beamIdx - 1;
    ssbIdx2 = min(2 * beamIdx, numSSB);

    for ssbIdx = [ssbIdx1 ssbIdx2]
        ssbSymbols = ssbInfo.OccupiedSymbols(ssbIdx, :);
        symbolGainLinear(ssbSymbols) = gainLinear;
        assignedActiveSymbols(ssbSymbols) = true;
    end

    searchSpace = wavegenConfig.SearchSpaces{1, ssbIdx1};
    pdcchStartSlot = searchSpace.SlotPeriodAndOffset(2);
    pdcchStartSym = searchSpace.StartSymbolWithinSlot;
    rmsiStartSym = pdcchStartSlot * symbolsPerSlot + pdcchStartSym + 1;

    pdschCfg = wavegenConfig.PDSCH{1, ssbIdx2};
    pdschSlot = pdschCfg.SlotAllocation;
    pdschSymAlloc = pdschCfg.SymbolAllocation;
    rmsiEndSym = pdschSlot * symbolsPerSlot + pdschSymAlloc(1) + pdschSymAlloc(2);

    rmsiSymbols = rmsiStartSym:rmsiEndSym;
    symbolGainLinear(rmsiSymbols) = gainLinear;
    assignedActiveSymbols(rmsiSymbols) = true;
end

unassignedActive = meta.ActiveSymbolMask & ~assignedActiveSymbols;
symbolGainLinear(unassignedActive) = 1;

waveformLength = size(meta.BaseWaveform, 1);
sampleGainAmplitude = ones(waveformLength, 1);
sampleHead = 1;
for symIdx = 1:numSymbols
    sampleTail = min(sampleHead + meta.SymbolLengthsAll(symIdx) - 1, waveformLength);
    sampleGainAmplitude(sampleHead:sampleTail) = sqrt(symbolGainLinear(symIdx));
    sampleHead = sampleTail + 1;
    if sampleHead > waveformLength
        break;
    end
end

beamProfile = struct();
beamProfile.UserAngle_deg = userAngle_deg;
beamProfile.BeamAngles_deg = beamAngles_deg;
beamProfile.BeamGainLinear = beamGainLinear;
beamProfile.BeamGain_dB = 10 * log10(beamGainLinear);
beamProfile.SSBGainLinear = ssbGainLinear;
beamProfile.SSBGain_dB = 10 * log10(ssbGainLinear);
beamProfile.SymbolGainLinear = symbolGainLinear(:);
beamProfile.SymbolGain_dB = 10 * log10(symbolGainLinear(:));
beamProfile.SampleGainAmplitude = sampleGainAmplitude;
beamProfile.MinBeamGain_dB = min(beamProfile.BeamGain_dB);
beamProfile.MaxBeamGain_dB = max(beamProfile.BeamGain_dB);
beamProfile.StrongestBeamIndex = find( ...
    beamGainLinear == max(beamGainLinear), 1, 'first');
beamProfile.ActiveSymbolCoverage = mean(assignedActiveSymbols(meta.ActiveSymbolMask));

end
