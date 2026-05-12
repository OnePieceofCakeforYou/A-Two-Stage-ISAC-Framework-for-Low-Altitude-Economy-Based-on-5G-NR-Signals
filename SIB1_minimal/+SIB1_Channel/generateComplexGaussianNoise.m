function noise = generateComplexGaussianNoise(signalSize, noisePower_W, seed)

rs = RandStream('mt19937ar', 'Seed', seed);

noise = sqrt(noisePower_W / 2) * ...
    (randn(rs, signalSize) + 1i * randn(rs, signalSize));

end
