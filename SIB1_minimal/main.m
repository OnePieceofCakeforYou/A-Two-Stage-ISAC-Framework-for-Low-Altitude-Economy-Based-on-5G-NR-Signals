
% Entry script: forwards optional workspace arguments to the main simulation.
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);

if exist('mainArgs', 'var') && ~isempty(mainArgs)
    if ~iscell(mainArgs)
        error('main:InvalidMainArgs', 'mainArgs must be a cell array.');
    end
    entryArgs = mainArgs;
else
    entryArgs = {};

    if exist('mainMode', 'var') && ~isempty(mainMode)
        entryArgs{end + 1} = mainMode;
    end

    if exist('mainOverrides', 'var') && ~isempty(mainOverrides)
        entryArgs{end + 1} = mainOverrides;
    end
end

% Keep the orchestration in the function so batch runs can return results.
results = Run_SIB1_SuccessRate_NoneVsSparse_Parfor(entryArgs{:});
