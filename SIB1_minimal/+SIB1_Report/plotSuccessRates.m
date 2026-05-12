function plotSuccessRates(rootDir, txPower_dBm, fineResults, pilotStrategies)

figure('Color', 'w', 'Position', [120, 120, 840, 560]);

plot(txPower_dBm, 100 * fineResults.SuccessRate, '-o', ...
    'LineWidth', 2, 'MarkerSize', 7);
grid on;
xlabel('Average active-interval total Tx power (dBm)');
ylabel('SIB1 decoding success rate (%)');
title('SIB1 access success rate: None vs Sparse');
legend(pilotStrategies, 'Location', 'southeast');
ylim([0 105]);

savefig(fullfile(rootDir, 'sib1_success_rate_none_vs_sparse_parfor.fig'));
saveas(gcf, fullfile(rootDir, 'sib1_success_rate_none_vs_sparse_parfor.png'));

end
