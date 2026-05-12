function [runMode, simOverrides] = parseInputs(varargin)

runMode = "default";
simOverrides = struct();

if nargin >= 1
    if ischar(varargin{1}) || isStringScalar(varargin{1})
        runMode = string(varargin{1});
    elseif isstruct(varargin{1})
        simOverrides = varargin{1};
    end
end

if nargin >= 2 && isstruct(varargin{2})
    simOverrides = varargin{2};
end

end
