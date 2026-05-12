function pos = generate_Coprime(numSubcarriers)

    base_pattern = [1, 6, 10];

    num_RBs = floor(numSubcarriers / 12);

    pos = zeros(1, num_RBs * length(base_pattern));

    for rb_idx = 0 : (num_RBs - 1)
        start_idx = rb_idx * length(base_pattern) + 1;
        end_idx = start_idx + length(base_pattern) - 1;

        pos(start_idx:end_idx) = base_pattern + rb_idx * 12;
    end


    pos = pos(pos <= numSubcarriers);
end
