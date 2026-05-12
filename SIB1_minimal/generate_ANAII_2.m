function S = generate_ANAII_2(M)

if nargin ~= 1
    error('Expected one argument: total sensor count M.');
end
if M < 8
    error('Total sensor count M is too small for ANAII-2. Use M >= 8.');
end

L1 = round(M / 6);
L3 = L1 - 1;
N2 = M - 4 * L1;

if L3 < 0 || N2 < 0
    warning('For M=%d, computed parameters are invalid (L3=%d, N2=%d). Try another M.', M, L3, N2);
    S = [];
    return;
end

fprintf('For M=%d, computed parameters: L1=%d, L3=%d, N2=%d\n', M, L1, L3, N2);

V11 = unique([0:2:2*L1, 2*L1 + 1]);
V22 = unique([0, 1:2:(2*L1 - 1)]);
V12_21 = 0:L3;

d12 = 2*L1 + 1;
d21 = 2*L1 - 1;

N1_plus_1 = 4*L1;

M1 = N1_plus_1 * (0:N2);

L12 = min(M1) - d12 * V12_21;
L11 = min(L12) - V11;

R21 = max(M1) + d21 * V12_21;
R22 = max(R21) + V22;

S_unaligned = [L11, L12, M1, R21, R22];

S_unique = unique(S_unaligned);

min_pos = min(S_unique);
S = S_unique - min_pos;

S = S(:)';

end
