function blockResults = runMonteCarloBlock( ...
    sim, txPower_dBm, numMonteCarlo, waveformsUnitPower, waveformMeta, ...
    config, channelModel, noisePower_W, rxConfig, seedOffset, useParallel)

numStrategies = numel(sim.PilotStrategies);
numPowerPoints = numel(txPower_dBm);
numTrials = numStrategies * numPowerPoints * numMonteCarlo;

successVec = false(numTrials, 1);
bchVec     = false(numTrials, 1);
dciVec     = false(numTrials, 1);
sib1Vec    = false(numTrials, 1);

trialPower_dBm = zeros(numTrials, 1);
trialWaveformsUnit = cell(numTrials, 1);
trialWaveformMeta = cell(numTrials, 1);
trialStratIdx = zeros(numTrials, 1);
trialPowerIdx = zeros(numTrials, 1);
trialRunIdx = zeros(numTrials, 1);

for trialIdx = 1:numTrials
    [trialRunIdx(trialIdx), trialPowerIdx(trialIdx), trialStratIdx(trialIdx)] = ...
        ind2sub([numMonteCarlo, numPowerPoints, numStrategies], trialIdx);
    trialPower_dBm(trialIdx) = txPower_dBm(trialPowerIdx(trialIdx));
    trialWaveformsUnit{trialIdx} = waveformsUnitPower{trialStratIdx(trialIdx)};
    trialWaveformMeta{trialIdx} = waveformMeta{trialStratIdx(trialIdx)};
end

if useParallel && isempty(gcp('nocreate'))
    warning('SIB1_MC:ParallelPoolMissing', ...
        ['Parallel execution was requested, but no active parallel pool ' ...
         'is available. Falling back to serial execution for this block.']);
    useParallel = false;
end

if useParallel
    try
        parfor trialIdx = 1:numTrials
            [successVec(trialIdx), bchVec(trialIdx), dciVec(trialIdx), sib1Vec(trialIdx)] = ...
                SIB1_MC.runOneTrial( ...
                    sim, trialPower_dBm(trialIdx), trialWaveformsUnit{trialIdx}, ...
                    trialWaveformMeta{trialIdx}, config, channelModel, noisePower_W, ...
                    rxConfig, seedOffset, trialStratIdx(trialIdx), ...
                    trialPowerIdx(trialIdx), trialRunIdx(trialIdx));
        end
    catch ME
        warning('SIB1_MC:ParforExecutionFailed', ...
            ['parfor execution failed and will be retried in serial mode.\n' ...
             'Reason: %s'], ME.message);
        useParallel = false;
    end
end

if ~useParallel
    for trialIdx = 1:numTrials
        [successVec(trialIdx), bchVec(trialIdx), dciVec(trialIdx), sib1Vec(trialIdx)] = ...
            SIB1_MC.runOneTrial( ...
                sim, trialPower_dBm(trialIdx), trialWaveformsUnit{trialIdx}, ...
                trialWaveformMeta{trialIdx}, config, channelModel, noisePower_W, ...
                rxConfig, seedOffset, trialStratIdx(trialIdx), ...
                trialPowerIdx(trialIdx), trialRunIdx(trialIdx));
    end
end

successFlags = reshape(successVec, [numMonteCarlo, numPowerPoints, numStrategies]);
bchFlags = reshape(bchVec, [numMonteCarlo, numPowerPoints, numStrategies]);
dciFlags = reshape(dciVec, [numMonteCarlo, numPowerPoints, numStrategies]);
sib1Flags = reshape(sib1Vec, [numMonteCarlo, numPowerPoints, numStrategies]);

blockResults = struct();
blockResults.TxPower_dBm = txPower_dBm(:);
blockResults.NumMonteCarlo = numMonteCarlo;
blockResults.SuccessFlags = successFlags;
blockResults.BCHFlags = bchFlags;
blockResults.DCIFlags = dciFlags;
blockResults.SIB1Flags = sib1Flags;
blockResults.SuccessRate = squeeze(mean(successFlags, 1));
blockResults.BCHSuccessRate = squeeze(mean(bchFlags, 1));
blockResults.DCISuccessRate = squeeze(mean(dciFlags, 1));
blockResults.SIB1SuccessRate = squeeze(mean(sib1Flags, 1));

end
