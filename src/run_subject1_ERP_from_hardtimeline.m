% First-pass ERP attempt from synthetic hard-timeline video onsets.
% This script does not overwrite APPEAR outputs or hard-timeline outputs.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

input_file = cfg.hard_timeline_eeg_file;
out_dir = cfg.erp_attempt_dir;

% ---- User-adjustable settings ----
target_event_type = 'hard_video_onset';
epoch_window_sec = [-0.2 1.0];
baseline_window_sec = [-0.2 0];
lowpass_hz = 30;

% Reject epochs whose max channel peak-to-peak, RMS, or global-mean deflection
% is a robust outlier.
% Larger = more permissive. Try 4-6 for exploratory ERP.
reject_mad_multiplier = 3;

% Plot channels. If labels are absent, these are simply channel numbers.
plot_channels = [1 15 30];

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

S = load(input_file);
if isfield(S, 'finalEEG_hardtimeline')
    EEG = S.finalEEG_hardtimeline;
elseif isfield(S, 'finalEEG')
    EEG = S.finalEEG;
elseif isfield(S, 'EEG')
    EEG = S.EEG;
else
    names = fieldnames(S);
    EEG = S.(names{1});
end

plot_channels = plot_channels(plot_channels >= 1 & plot_channels <= EEG.nbchan);
if isempty(plot_channels)
    plot_channels = unique(round(linspace(1, EEG.nbchan, min(3, EEG.nbchan))));
end

event_types = cell(numel(EEG.event), 1);
event_latencies = nan(numel(EEG.event), 1);
for k = 1:numel(EEG.event)
    event_types{k} = char(string(EEG.event(k).type));
    event_latencies(k) = double(EEG.event(k).latency);
end
target_latencies = event_latencies(strcmp(event_types, target_event_type));

sample_offsets = round(epoch_window_sec(1) * EEG.srate):round(epoch_window_sec(2) * EEG.srate);
time_sec = sample_offsets / EEG.srate;
baseline_idx = time_sec >= baseline_window_sec(1) & time_sec < baseline_window_sec(2);

epochs = nan(EEG.nbchan, numel(sample_offsets), numel(target_latencies));
kept_source_event = false(numel(target_latencies), 1);
for e = 1:numel(target_latencies)
    idx = round(target_latencies(e)) + sample_offsets;
    if idx(1) >= 1 && idx(end) <= EEG.pnts
        epochs(:, :, e) = double(EEG.data(:, idx));
        kept_source_event(e) = true;
    end
end
epochs = epochs(:, :, kept_source_event);
target_latencies = target_latencies(kept_source_event);

% Baseline correction per epoch and channel.
for e = 1:size(epochs, 3)
    base = mean(epochs(:, baseline_idx, e), 2, 'omitnan');
    epochs(:, :, e) = epochs(:, :, e) - base;
end

% Low-pass filter each epoch for ERP visualization.
filter_applied = false;
if exist('butter', 'file') == 2 && exist('filtfilt', 'file') == 2 && ~isempty(lowpass_hz)
    [b, a] = butter(4, lowpass_hz / (EEG.srate / 2), 'low');
    for e = 1:size(epochs, 3)
        epochs(:, :, e) = filtfilt(b, a, epochs(:, :, e)')';
    end
    filter_applied = true;
end

% Robust trial rejection based on maximum channel peak-to-peak.
epoch_ptp = squeeze(max(max(epochs, [], 2), [], 1) - min(min(epochs, [], 2), [], 1));
epoch_ptp = epoch_ptp(:);
epoch_rms = squeeze(sqrt(mean(mean(epochs .^ 2, 2, 'omitnan'), 1, 'omitnan')));
epoch_rms = epoch_rms(:);
epoch_global_abs = squeeze(max(abs(mean(epochs, 1, 'omitnan')), [], 2));
epoch_global_abs = epoch_global_abs(:);

ptp_med = median(epoch_ptp, 'omitnan');
ptp_mad = 1.4826 * median(abs(epoch_ptp - ptp_med), 'omitnan');
if ptp_mad <= 0 || ~isfinite(ptp_mad)
    ptp_threshold = inf;
else
    ptp_threshold = ptp_med + reject_mad_multiplier * ptp_mad;
end

rms_med = median(epoch_rms, 'omitnan');
rms_mad = 1.4826 * median(abs(epoch_rms - rms_med), 'omitnan');
if rms_mad <= 0 || ~isfinite(rms_mad)
    rms_threshold = inf;
else
    rms_threshold = rms_med + reject_mad_multiplier * rms_mad;
end

global_abs_med = median(epoch_global_abs, 'omitnan');
global_abs_mad = 1.4826 * median(abs(epoch_global_abs - global_abs_med), 'omitnan');
if global_abs_mad <= 0 || ~isfinite(global_abs_mad)
    global_abs_threshold = inf;
else
    global_abs_threshold = global_abs_med + reject_mad_multiplier * global_abs_mad;
end

good_epochs = isfinite(epoch_ptp) & isfinite(epoch_rms) & isfinite(epoch_global_abs) & ...
    epoch_ptp <= ptp_threshold & ...
    epoch_rms <= rms_threshold & ...
    epoch_global_abs <= global_abs_threshold;

epochs_good = epochs(:, :, good_epochs);
erp = mean(epochs_good, 3, 'omitnan');
global_mean_erp = mean(erp, 1, 'omitnan');
gfp = std(erp, 0, 1, 'omitnan');

finalERP = struct();
finalERP.erp = erp;
finalERP.epochs_good = epochs_good;
finalERP.time_sec = time_sec;
finalERP.srate = EEG.srate;
finalERP.target_event_type = target_event_type;
finalERP.good_epochs = good_epochs;
finalERP.epoch_ptp = epoch_ptp;
finalERP.epoch_rms = epoch_rms;
finalERP.epoch_global_abs = epoch_global_abs;
finalERP.ptp_threshold = ptp_threshold;
finalERP.rms_threshold = rms_threshold;
finalERP.global_abs_threshold = global_abs_threshold;
finalERP.settings = struct( ...
    'epoch_window_sec', epoch_window_sec, ...
    'baseline_window_sec', baseline_window_sec, ...
    'lowpass_hz', lowpass_hz, ...
    'filter_applied', filter_applied, ...
    'reject_mad_multiplier', reject_mad_multiplier);

save(fullfile(out_dir, [cfg.run_id '_ERP_attempt.mat']), 'finalERP', '-v7.3');

report_file = fullfile(out_dir, 'ERP_attempt_report.txt');
fid = fopen(report_file, 'w');
fprintf(fid, 'ERP attempt report: %s\n', cfg.run_id);
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'Input EEG: %s\n', input_file);
fprintf(fid, 'Target event type: %s\n', target_event_type);
fprintf(fid, 'Epoch window: %.3f to %.3f s\n', epoch_window_sec(1), epoch_window_sec(2));
fprintf(fid, 'Baseline window: %.3f to %.3f s\n', baseline_window_sec(1), baseline_window_sec(2));
fprintf(fid, 'Low-pass filter: %.1f Hz, applied=%d\n', lowpass_hz, filter_applied);
fprintf(fid, 'Candidate events found: %d\n', numel(event_latencies(strcmp(event_types, target_event_type))));
fprintf(fid, 'Epochs inside data bounds: %d\n', size(epochs, 3));
fprintf(fid, 'Epochs accepted: %d\n', sum(good_epochs));
fprintf(fid, 'Epochs rejected: %d\n', sum(~good_epochs));
fprintf(fid, 'Reject threshold max channel peak-to-peak: %.3f uV\n', ptp_threshold);
fprintf(fid, 'Reject threshold epoch RMS: %.3f uV\n', rms_threshold);
fprintf(fid, 'Reject threshold global-mean max abs: %.3f uV\n', global_abs_threshold);
fprintf(fid, 'Median epoch max channel peak-to-peak: %.3f uV\n', ptp_med);
fprintf(fid, 'MAD-scaled PTP spread: %.3f uV\n', ptp_mad);
fprintf(fid, 'Median epoch RMS: %.3f uV\n', rms_med);
fprintf(fid, 'MAD-scaled RMS spread: %.3f uV\n', rms_mad);
fprintf(fid, 'Median global-mean max abs: %.3f uV\n', global_abs_med);
fprintf(fid, 'MAD-scaled global-mean max abs spread: %.3f uV\n', global_abs_mad);
fclose(fid);

T = table(time_sec(:), global_mean_erp(:), gfp(:), ...
    'VariableNames', {'time_sec', 'global_mean_erp_uV', 'global_field_power_uV'});
for c = 1:numel(plot_channels)
    ch = plot_channels(c);
    T.(sprintf('ch%02d_erp_uV', ch)) = erp(ch, :)';
end
writetable(T, fullfile(out_dir, 'ERP_waveforms.csv'));

% Figure 1: epoch count summary.
fig = figure('Visible', 'off', 'Position', [100 100 700 450]);
bar([sum(good_epochs), sum(~good_epochs)]);
set(gca, 'XTickLabel', {'Accepted', 'Rejected'});
ylabel('Epoch count');
title('ERP epoch rejection summary');
grid on;
saveas(fig, fullfile(out_dir, '01_epoch_rejection_summary.png'));
close(fig);

% Figure 2: selected channel ERPs.
fig = figure('Visible', 'off', 'Position', [100 100 1100 600]);
hold on;
for c = 1:numel(plot_channels)
    ch = plot_channels(c);
    plot(time_sec, erp(ch, :), 'LineWidth', 1.5);
end
xline(0, '--k');
yline(0, ':k');
xlabel('Time from video onset (s)');
ylabel('Amplitude (uV, baseline corrected)');
title('First-pass ERP: selected channels');
legend(compose('Ch%d', plot_channels), 'Location', 'best');
grid on;
saveas(fig, fullfile(out_dir, '02_ERP_selected_channels.png'));
close(fig);

% Figure 3: global mean and global field power.
fig = figure('Visible', 'off', 'Position', [100 100 1100 600]);
yyaxis left;
plot(time_sec, global_mean_erp, 'LineWidth', 1.5);
ylabel('Global mean ERP (uV)');
yyaxis right;
plot(time_sec, gfp, 'LineWidth', 1.5);
ylabel('Global field power (uV)');
xline(0, '--k');
xlabel('Time from video onset (s)');
title('First-pass ERP: global mean and GFP');
grid on;
saveas(fig, fullfile(out_dir, '03_ERP_global_mean_GFP.png'));
close(fig);

% Figure 4: trial image of global mean signal.
trial_mean = squeeze(mean(epochs_good, 1, 'omitnan'))';
fig = figure('Visible', 'off', 'Position', [100 100 1100 650]);
imagesc(time_sec, 1:size(trial_mean, 1), trial_mean);
axis xy;
xline(0, '--w');
xlabel('Time from video onset (s)');
ylabel('Accepted epoch');
title('Trial image: mean across channels');
colorbar;
saveas(fig, fullfile(out_dir, '04_trial_image_global_mean.png'));
close(fig);

% Figure 5: channel-by-time ERP matrix.
fig = figure('Visible', 'off', 'Position', [100 100 1100 650]);
imagesc(time_sec, 1:EEG.nbchan, erp);
axis xy;
xline(0, '--w');
xlabel('Time from video onset (s)');
ylabel('Channel');
title('ERP matrix: channels by time');
colorbar;
saveas(fig, fullfile(out_dir, '05_channel_ERP_matrix.png'));
close(fig);

disp(['ERP attempt report saved: ' report_file]);
disp(['ERP attempt MAT saved: ' fullfile(out_dir, [cfg.run_id '_ERP_attempt.mat'])]);
disp(['ERP figures saved in: ' out_dir]);
