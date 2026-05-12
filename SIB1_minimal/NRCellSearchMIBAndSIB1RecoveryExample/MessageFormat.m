

classdef MessageFormat < matlab.mixin.CustomDisplay

    properties
        AlignedWidth = [];
    end

    properties (SetAccess = private, Dependent)
        Width;
        PaddingWidth;
    end

    properties (Dependent, Access = private)
        ManagedPaddingField;
    end

    methods

        function bits = toBits(obj)

            propName = getActiveFieldProperties(obj);
            bits = logical([]);
            for n = 1:numel(propName)
                bits = [bits; obj.(propName{n}).toBits];
            end
        end

        function [obj, bitpos] = fromBits(obj,bits)

            mwid = obj.Width;
            if length(bits) < mwid
                bits(mwid) = 0;
            end

            [propName] = getActiveFieldProperties(obj);
            bitpos = 1;
            for n = 1:numel(propName)
                bitwid = obj.(propName{n}).Width;
                obj.(propName{n}) = obj.(propName{n}).fromBits(bits(bitpos:bitpos+bitwid-1));
                bitpos = bitpos + bitwid;
            end

            bitpos = bitpos-1;
        end

        function ifo = info(obj,opts)

            if nargin < 2
                opts = [];
            end
            [propName,propNameOut] = getActiveFieldProperties(obj);

            propNameS = propNameOut';          % Create row of field names
            propNameS{2,end} = [];
            ifo = struct(propNameS{:});
            for n = 1:numel(propName)
                ifo.(propNameOut{n}) = obj.(propName{n}).info(opts);
            end
        end

        function w = get.PaddingWidth(obj)
            if isempty(obj.AlignedWidth)
                w = 0;
            else
                w = obj.AlignedWidth - calcWidth(obj);
            end
        end

        function w = get.Width(obj)
            if  isempty(obj.AlignedWidth)
                w = calcWidth(obj);
            else
                w = obj.AlignedWidth;
            end
        end

        function value = get.ManagedPaddingField(obj)
            value = BitField(max(0,obj.PaddingWidth));
        end

        function obj = set.ManagedPaddingField(obj,~)
        end

        function obj = set.Width(obj,~)
            error("You cannot set the read-only property 'Width'");
        end
        function obj = set.PaddingWidth(obj,~)
            error("You cannot set the read-only property 'PaddingWidth'");
        end

        function obj = subsasgn(obj, S, B)

            vpeek = builtin('subsref', obj, S);
            if isa(vpeek,'BitField') && ~isa(B,'BitField')
                 S = [S,struct('type','.','subs','Value')];
            end
            obj = builtin('subsasgn', obj, S, B);

        end

        function V = subsref(obj, S)

            V = builtin('subsref', obj, S);
            if isa(V,'BitField')
                V = V.Value;
            end

        end

    end

    methods (Access = private)

        function [p,po] = getActiveFieldProperties(obj,excpadding)

            if nargin==1
                excpadding = false;
            end

            p = properties(obj);
            p = p(1:end-3);
            po = p;

            if ~(excpadding || isempty(obj.AlignedWidth))
               paddingpos = find(strcmpi('padding',p),1);
               if isempty(paddingpos)
                   paddingpos = length(p)+1;
               end
               p{paddingpos} = 'ManagedPaddingField';
               po{paddingpos} = 'Padding';
            else
               paddingpos = strcmpi('padding',p);
               p(paddingpos) = [];
               po(paddingpos) = [];
            end
        end

    end

    methods (Access = protected)

        function b = isInactiveProperty(obj,p)
            b = isempty(obj.AlignedWidth) && strcmp(p,'PaddingWidth');
        end

        function header = getHeader(obj)
            if ~isscalar(obj)
                header = getHeader@matlab.mixin.CustomDisplay(obj);
            else
                headerStr = matlab.mixin.CustomDisplay.getClassNameForHeader(obj);
                headerStr = ['  ', headerStr,' with field values:'];
                header = sprintf('%s\n',headerStr);
            end
        end

        function groups = getPropertyGroups(obj)

            if ~isscalar(obj)
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
                return;
            end

            propName  = properties(obj);
            mc = meta.class.fromName(class(obj));
            allProperties = {mc.PropertyList.Name};
            if any(strcmpi(allProperties,'CustomPropList'))
                propName = obj.CustomPropList;
            end
            propVal = cell(numel(propName),1);
            activeIdx = true(size(propName));
            nonFieldIdx = false(size(propName));
            readOnlyIdx = false(size(propName));
            constIdx = false(size(propName));
            mc = meta.class.fromName(class(obj));
            for n = 1:numel(propName)
                id = cellfun(@(x)strcmp(x,propName{n}),{mc.PropertyList.Name});
                readOnlyIdx(n) = strcmp(mc.PropertyList(id).SetAccess,'private') && strcmp(mc.PropertyList(id).GetAccess,'public');
                constIdx(n) = mc.PropertyList(id).Constant;

                if isInactiveProperty(obj,propName{n})
                       activeIdx(n) = false;
                else
                if readOnlyIdx(n)
                    propVal{n} = obj.(propName{n});
                else
                    if isa(obj.(propName{n}),'BitField')
                        propVal{n} = obj.(propName{n}).Value;
                    else
                        nonFieldIdx(n) = ~isa(obj.(propName{n}),'MessageFormat');
                        propVal{n} = obj.(propName{n});
                    end
                end
                end
            end
            readOnlyPropList = cell2struct(propVal(activeIdx&readOnlyIdx),propName(activeIdx&readOnlyIdx));
            normalPropList = cell2struct(propVal(~nonFieldIdx&activeIdx&~readOnlyIdx&~constIdx),propName(~nonFieldIdx&activeIdx&~readOnlyIdx&~constIdx));
            nonFieldPropList = cell2struct(propVal(nonFieldIdx&activeIdx&~readOnlyIdx&~constIdx),propName(nonFieldIdx&activeIdx&~readOnlyIdx&~constIdx));
            constPropList = cell2struct(propVal(activeIdx&constIdx),propName(activeIdx&constIdx));
            groups = [matlab.mixin.util.PropertyGroup(normalPropList) ...
                      matlab.mixin.util.PropertyGroup(nonFieldPropList,'Writeable properties:') ...
                      matlab.mixin.util.PropertyGroup(readOnlyPropList,'Read-only properties:')];
            if ~isempty(fields(constPropList))
                groups = [groups matlab.mixin.util.PropertyGroup(constPropList,'Constant properties:')];
            end
        end

    end

end


function w = calcWidth(obj)
    [propName] = getActiveFieldProperties(obj,1);
    w = 0;
    for n = 1:numel(propName)
        w = w+obj.(propName{n}).Width;
    end
end


