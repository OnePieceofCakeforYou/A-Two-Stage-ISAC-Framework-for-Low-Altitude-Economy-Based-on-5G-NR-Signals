

classdef MIB < MessageFormat

    properties

        systemFrameNumber = BitField(6);

        subCarrierSpacingCommon = BitField(1);

        ssb_SubcarrierOffset = BitField(4);

        dmrs_TypeA_Position = BitField(1);

        pdcch_ConfigSIB1 = PDCCH_ConfigSIB1;

        cellBarred = BitField(1);

        intraFreqReselection = BitField(1);

        spare = BitField(1);

    end

end
