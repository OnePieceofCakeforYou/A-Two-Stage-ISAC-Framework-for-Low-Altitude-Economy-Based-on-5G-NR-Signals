

function [rxWaveform, freqOffset, NID2] = hSSBurstFrequencyCorrect(rxWaveform,ssbBlockPattern,rxSampleRate,searchBW,displayFigure)

    scs = hSSBurstSubcarrierSpacing(ssbBlockPattern);
    if nargin < 4
        searchBW = 6*scs;
    end

    if nargin < 5
        displayFigure = false;
    end

    syncNfft = 256;
    syncSR = syncNfft*scs*1e3;
    nrbSSB = 20;
    syncOfdmInfo = nrOFDMInfo(nrbSSB, scs,'SampleRate',syncSR,'Nfft',syncNfft);

    subsPSS = nrPSSIndices('IndexStyle','subscript');
    kPSS = subsPSS(:,1);

    refGrid = zeros([nrbSSB*12 2]);

    fshifts = (-searchBW:scs:searchBW) * 1e3/2;
    peak_value = zeros(numel(fshifts),3);
    peak_index = zeros(numel(fshifts),3);
    t = (0:size(rxWaveform,1)-1).' / rxSampleRate;
    for fIdx = 1:numel(fshifts)

        coarseFrequencyOffset = fshifts(fIdx);
        rxWaveformFreqCorrected = rxWaveform .* exp(-1i*2*pi*coarseFrequencyOffset*t);

        rxWaveformDS = resample(rxWaveformFreqCorrected,syncSR,rxSampleRate);

        for NID2 = [0 1 2]
            refGrid(kPSS,2,NID2+1) = nrPSS(NID2);

            nSlot = 0;
            [~,corr] = nrTimingEstimate(rxWaveformDS,nrbSSB,scs,nSlot,refGrid(:,:,NID2+1),'SampleRate',syncSR,'Nfft',syncNfft);
            corr = sum(abs(corr),2);
            [peak_value(fIdx,NID2+1),peak_index(fIdx,NID2+1)] = max(corr);
            peak_index(fIdx,NID2+1) = peak_index(fIdx,NID2+1) + syncOfdmInfo.SymbolLengths(1);

        end
    end

    [fIdx,NID2] = find(peak_value==max(peak_value(:)));
    coarseFrequencyOffset = fshifts(fIdx);
    NID2 = NID2 - 1;

    rxWaveformFreqCorrected = rxWaveform .* exp(-1i*2*pi*coarseFrequencyOffset*t);

    rxWaveformDS = resample(rxWaveformFreqCorrected,syncSR,rxSampleRate);

    if displayFigure
        figure;
        hold on;
        plot(fshifts/1e3,peak_value);
        title('PSS Correlations versus Frequency Offset');
        ylabel('Magnitude');
        xlabel('Frequency Offset (kHz)');

        plot(coarseFrequencyOffset/1e3,peak_value(fIdx,NID2+1),'kx','LineWidth',2,'MarkerSize',8);
        lgd = legend;
        lgd.Interpreter = 'latex';
        legends = "$N_{ID}^{(2)}$ = " + num2cell(0:2);
        legend([legends "coarse $\Delta_f$ = " + num2str(coarseFrequencyOffset) + ", $N_{ID}^{(2)}$ = " + num2str(NID2)],'Location','East');
    end

    offset = peak_index(fIdx,NID2+1) - 1;

    fineFrequencyOffset = hSSBurstFineFrequencyOffset(rxWaveformDS(1+offset:end,:),syncOfdmInfo);

    freqOffset = coarseFrequencyOffset + fineFrequencyOffset;

    rxWaveform = rxWaveform .* exp(-1i*2*pi*freqOffset*t);

end

function frequencyOffset = hSSBurstFineFrequencyOffset(waveform,ofdmInfo)

    Lcp = ofdmInfo.CyclicPrefixLengths(2);
    Lu = ofdmInfo.Nfft;
    Lsym = Lcp + Lu;

    delayed = [zeros(Lu,size(waveform,2)); waveform(1:end-Lu,:)];
    cpProduct = waveform .* conj(delayed);

    cpXCorr = filter(ones([Lcp 1]),1,cpProduct);

    y = cpXCorr;
    cpXCorrDelayed = cpXCorr;
    for k = 1:3
        cpXCorrDelayed = [zeros(Lsym,size(waveform,2)); cpXCorrDelayed(1:end-Lsym,:)];
        y = y + cpXCorrDelayed;
    end

    cpCorrIndex = Lu + Lcp + 3*Lsym;
    scs = ofdmInfo.SampleRate/ofdmInfo.Nfft;
    frequencyOffset =  scs * angle(mean(y(cpCorrIndex,:))) / (2*pi);

end
