function userAzimuth_deg = sampleUEAzimuthDeg(sim, seed)

azRange_deg = sort(sim.UEAzimuthRange_deg);

if ~isfield(sim, 'RandomizeUEAzimuth') || ~sim.RandomizeUEAzimuth || ...
        azRange_deg(1) == azRange_deg(2)
    userAzimuth_deg = mean(azRange_deg);
    return;
end

rs = RandStream('mt19937ar', 'Seed', seed);
userAzimuth_deg = azRange_deg(1) + diff(azRange_deg) * rand(rs, 1);

end
