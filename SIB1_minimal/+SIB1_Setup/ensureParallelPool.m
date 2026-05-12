function useParallel = ensureParallelPool(numWorkers)

pool = gcp('nocreate');
if ~isempty(pool)
    poolClass = class(pool);
    workerCountMatches = isempty(numWorkers) || pool.NumWorkers == numWorkers;

    if contains(poolClass, 'ProcessPool') && workerCountMatches
        useParallel = true;
        return;
    end

    delete(pool);
end

profileCandidates = {'Processes', 'threads'};
failureMessages = cell(1, numel(profileCandidates));

for profileIdx = 1:numel(profileCandidates)
    profileName = profileCandidates{profileIdx};
    try
        if isempty(numWorkers)
            parpool(profileName);
        else
            parpool(profileName, numWorkers);
        end

        useParallel = true;
        if profileIdx > 1
            warning('SIB1_Setup:ParallelPoolFallback', ...
                ['Unable to start the preferred process-based parallel pool. ' ...
                 'Fell back to "%s".'], profileName);
        end
        return;
    catch ME
        failureMessages{profileIdx} = sprintf('%s: %s', profileName, ME.message);
    end
end

useParallel = false;
warning('SIB1_Setup:ParallelPoolUnavailable', ...
    ['Unable to start any local parallel pool. The simulation will ' ...
     'continue in serial mode.\n%s'], strjoin(failureMessages, '\n'));

end
