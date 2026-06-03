% Plot a quick N400-window check from the current ERP attempt.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

erp_dir = cfg.erp_attempt_dir;
csv_file = fullfile(erp_dir, 'ERP_waveforms.csv');
out_file = fullfile(erp_dir, '06_N400_window_check.png');

T = readtable(csv_file);
t = T.time_sec;

fig = figure('Visible', 'off', 'Position', [100 100 1200 650]);
hold on;

yl = [-8 8];
patch([0.3 0.5 0.5 0.3], [yl(1) yl(1) yl(2) yl(2)], ...
    [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.7);

plot(t, T.global_mean_erp_uV, 'k', 'LineWidth', 2);
plot(t, T.ch01_erp_uV, 'LineWidth', 1.4);
plot(t, T.ch15_erp_uV, 'LineWidth', 1.4);
plot(t, T.ch30_erp_uV, 'LineWidth', 1.4);

xline(0, '--k');
yline(0, ':k');
ylim(yl);
xlabel('Time from video onset (s)');
ylabel('Amplitude (uV, baseline corrected)');
title('N400 window check: 300-500 ms shaded');
legend({'300-500 ms', 'Global mean', 'Ch1', 'Ch15', 'Ch30'}, 'Location', 'best');
grid on;

saveas(fig, out_file);
close(fig);

disp(['N400 check figure saved: ' out_file]);
