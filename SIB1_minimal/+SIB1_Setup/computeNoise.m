function noiseInfo = computeNoise(sim)

noiseDensityWithNF_dBmHz = sim.NoisePSD_dBmHz + sim.ReceiverNoiseFigure_dB;

noisePSD_WHz = 10^((noiseDensityWithNF_dBmHz - 30) / 10);

noisePower_W = noisePSD_WHz * sim.RFFrontEndBandwidth_Hz;
noisePower_dBm = 10 * log10(noisePower_W) + 30;

noiseInfo = struct();
noiseInfo.DensityWithNF_dBmHz = noiseDensityWithNF_dBmHz;
noiseInfo.PSD_WHz = noisePSD_WHz;
noiseInfo.Power_W = noisePower_W;
noiseInfo.Power_dBm = noisePower_dBm;

end
