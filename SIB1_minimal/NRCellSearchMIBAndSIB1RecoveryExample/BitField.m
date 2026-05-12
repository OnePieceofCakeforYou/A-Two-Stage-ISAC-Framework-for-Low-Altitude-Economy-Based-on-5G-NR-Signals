

classdef BitField

    properties (Dependent)
        Value
        Width
    end

    properties (SetAccess = private)
        WidthValues = [];
    end

    methods

        function obj = BitField(widthvalues,initwidth,initvalue)
            if nargin > 0
                obj.WidthValues = widthvalues;
                if nargin < 2
                    initwidth = min(widthvalues);
                end
                obj.Width = initwidth;
                if nargin > 2
                    obj.Value = initvalue;
                end
            end
        end

        function ifo = info(obj,opts)
            if nargin > 1 && any(strcmpi(opts,{'width','fieldsizes'}))
                ifo = obj.Width;
            elseif nargin > 1 && any(strcmpi(opts,'widthvalues'))
                ifo = obj.WidthValues;
            else
                ifo = obj.Value;
            end
        end

        function bits = toBits(obj)

            bits = int8(dec2bin(obj.Value,obj.Width) == '1')';
        end

        function obj = fromBits(obj,B)
            wl = min(obj.Width,length(B));
            obj.Value = sum(reshape(B(1:wl)~=0,1,[]).*2.^(wl-1:-1:0));
        end

        function obj = set.Value(obj,B)
            if length(B) > 1
                wl = min(obj.Width,length(B));
                B = sum(reshape(B(1:wl)~=0,1,[]).*2.^(wl-1:-1:0));
            end

            if ~isempty(B) || obj.Width == 0
                obj.IValue = mod(B,2^obj.Width);
            end
        end

        function v = get.Value(obj)
            v = obj.IValue;
            if obj.IWidth == 0
               v = [];
            end
        end

        function obj = set.Width(obj,B)
            if isempty(B) || B < 0
               error("The field bit width must be positive.")
            end
            if ~isempty(obj.WidthValues) && ~any(B == obj.WidthValues)
                warning("The field bit width (%d) is not one of the set specified (%s) for this field.", B, strjoin(string(obj.WidthValues),','));
            end
            obj.IWidth = B;
            obj.Value = obj.Value;
            if isempty(obj.Value) && B > 0
                obj.Value = 0;
            end
        end

        function w = get.Width(obj)
            w = obj.IWidth;
        end

    end

    properties (Access = private)
        IValue = 0;
        IWidth = 1;
    end

end



