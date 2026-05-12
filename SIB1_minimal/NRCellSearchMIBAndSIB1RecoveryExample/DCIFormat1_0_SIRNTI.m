

classdef DCIFormat1_0_SIRNTI < MessageFormat

    properties

        FrequencyDomainResources = BitField();

        TimeDomainResources = BitField(4);

        VRBToPRBMapping = BitField(1);

        ModulationCoding = BitField(5);

        RedundancyVersion = BitField(2);

        SystemInformationIndicator = BitField(1);

        ReservedBits = BitField(15);

    end

    methods

        function obj = DCIFormat1_0_SIRNTI(nsizebwp,sharedspectrum)

            N = ceil(log2(nsizebwp*(nsizebwp+1)/2));
            obj.FrequencyDomainResources = BitField(N);

            if nargin>1 && sharedspectrum
                obj.ReservedBits = BitField(17);
            end

        end

    end

end
