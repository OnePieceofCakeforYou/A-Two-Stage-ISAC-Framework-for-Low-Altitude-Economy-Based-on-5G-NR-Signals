function [UF4BL,Nb,Nt] = generate_UF4BL(N)

if N < 11
    error('UF-4BL is defined only for total sensor count N >= 11.');
elseif N < 32
end

Nb = floor((N - 8) / 8);
Nt = N - 4*Nb - 6;



I1 = 0; S1 = 3; N1 = 2;
ula1_pos = I1 : S1 : (I1 + (N1 - 1) * S1);

I2 = 7; S2 = 4; N2 = Nb;
ula2_pos = I2 : S2 : (I2 + (N2 - 1) * S2);

I3 = 4*Nb + 8; S3 = 1; N3 = 2;
ula3_pos = I3 : S3 : (I3 + (N3 - 1) * S3);

I4 = 4*Nb + 15; S4 = 4; N4 = Nb;
ula4_pos = I4 : S4 : (I4 + (N4 - 1) * S4);

I5 = 8*Nb + 19; S5 = 4*Nb + 7; N5 = Nt;
ula5_pos = I5 : S5 : (I5 + (N5 - 1) * S5);

I6 = 4*Nt*Nb + 7*Nt + 4*Nb + 19; S6 = 4; N6 = Nb;
ula6_pos = I6 : S6 : (I6 + (N6 - 1) * S6);

I7 = 4*Nt*Nb + 7*Nt + 8*Nb + 18; S7 = 2; N7 = 2;
ula7_pos = I7 : S7 : (I7 + (N7 - 1) * S7);

I8 = 4*Nt*Nb + 7*Nt + 8*Nb + 25; S8 = 4; N8 = Nb;
ula8_pos = I8 : S8 : (I8 + (N8 - 1) * S8);


all_sensors = [ula1_pos, ula2_pos, ula3_pos, ula4_pos, ula5_pos, ula6_pos, ula7_pos, ula8_pos];

UF4BL = unique(all_sensors)';

end
