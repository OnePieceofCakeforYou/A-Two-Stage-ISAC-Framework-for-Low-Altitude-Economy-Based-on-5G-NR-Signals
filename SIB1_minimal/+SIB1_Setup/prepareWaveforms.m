function [waveformsUnitPower, waveformMeta, sampleRate, activeDutyCycle] = ...
    prepareWaveforms(config, pilotStrategies)

numStrategies = numel(pilotStrategies);
waveformsUnitPower = cell(1, numStrategies);
waveformMeta = cell(1, numStrategies);

for stratIdx = 1:numStrategies
    [txWaveformRaw, meta] = GenerateSIB1WaveformWithInsertion( ...
        config, pilotStrategies{stratIdx});

    activePower_W = mean(abs(txWaveformRaw(meta.ActiveSampleMask)).^2);

    waveformsUnitPower{stratIdx} = txWaveformRaw / sqrt(activePower_W);
    waveformMeta{stratIdx} = meta;
    waveformMeta{stratIdx}.ActivePower_W = activePower_W;
end

sampleRate = waveformMeta{1}.SampleRate;
activeDutyCycle = mean(waveformMeta{1}.ActiveSampleMask);

end
