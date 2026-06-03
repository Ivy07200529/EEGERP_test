clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

outdir = cfg.subject_out_dir;
qcdir = fullfile(outdir, 'QC');
if ~exist(qcdir, 'dir')
    mkdir(qcdir);
end

if exist(cfg.appear_dir, 'dir')
    addpath(fullfile(cfg.appear_dir, 'eeglab2019_0'));
    addpath(fullfile(cfg.appear_dir, 'eeglab2019_0', 'plugins', 'bva-io1.5.13'));
end

finalFile = cfg.final_eeg_file;
midFile = fullfile(outdir, [cfg.run_id '_eeg_p-1.vhdr']);

load(finalFile, 'finalEEG');
EEG_final = finalEEG;

EEG_mid = [];
try
    EEG_mid = pop_loadbv(outdir, [cfg.run_id '_eeg_p-1.vhdr']);
catch ME
    warning('Could not load intermediate BVA file: %s', ME.message);
end

data = double(EEG_final.data);
fs = EEG_final.srate;
nChan = size(data, 1);
nSamp = size(data, 2);
durationSec = nSamp / fs;

nonfiniteCount = sum(~isfinite(data(:)));
chanRMS = sqrt(mean(data.^2, 2, 'omitnan'));
chanStd = std(data, 0, 2, 'omitnan');
chanPtP = max(data, [], 2) - min(data, [], 2);

eventTypes = {};
eventCounts = [];
if isfield(EEG_final, 'event') && ~isempty(EEG_final.event)
    rawTypes = cell(1, numel(EEG_final.event));
    for ii = 1:numel(EEG_final.event)
        if isfield(EEG_final.event(ii), 'type')
            rawTypes{ii} = char(string(EEG_final.event(ii).type));
        else
            rawTypes{ii} = '<missing>';
        end
    end
    eventTypes = unique(rawTypes);
    eventCounts = zeros(size(eventTypes));
    for ii = 1:numel(eventTypes)
        eventCounts(ii) = sum(strcmp(rawTypes, eventTypes{ii}));
    end
end

% Write summary text.
summaryPath = fullfile(qcdir, 'qc_summary.txt');
fid = fopen(summaryPath, 'w');
fprintf(fid, 'APPEAR QC summary: %s\n', cfg.run_id);
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'Final EEG file: %s\n', finalFile);
fprintf(fid, 'Channels: %d\n', nChan);
fprintf(fid, 'Samples: %d\n', nSamp);
fprintf(fid, 'Sampling rate: %.3f Hz\n', fs);
fprintf(fid, 'Duration: %.2f s / %.2f min\n', durationSec, durationSec/60);
fprintf(fid, 'Non-finite samples: %d\n', nonfiniteCount);
fprintf(fid, 'Median channel RMS: %.3f uV\n', median(chanRMS, 'omitnan'));
fprintf(fid, 'Max channel RMS: %.3f uV\n', max(chanRMS));
fprintf(fid, 'Median channel peak-to-peak: %.3f uV\n', median(chanPtP, 'omitnan'));
fprintf(fid, 'Max channel peak-to-peak: %.3f uV\n\n', max(chanPtP));
fprintf(fid, 'Event types:\n');
for ii = 1:numel(eventTypes)
    fprintf(fid, '  %s: %d\n', eventTypes{ii}, eventCounts(ii));
end
fclose(fid);

% Write per-channel metrics.
chanTable = table((1:nChan)', chanRMS, chanStd, chanPtP, ...
    'VariableNames', {'channel', 'rms_uV', 'std_uV', 'peak_to_peak_uV'});
writetable(chanTable, fullfile(qcdir, 'channel_metrics.csv'));

if ~isempty(eventTypes)
    eventTable = table(eventTypes(:), eventCounts(:), ...
        'VariableNames', {'event_type', 'count'});
    writetable(eventTable, fullfile(qcdir, 'event_counts.csv'));
end

% Figure 1: final EEG trace, first 60 seconds, channels offset.
fig = figure('Visible', 'off', 'Position', [100 100 1400 850]);
plotSeconds = min(60, durationSec);
idx = 1:round(plotSeconds * fs);
offset = 300;
plot((idx-1)/fs, data(:, idx)' + (0:nChan-1)*offset);
xlabel('Time (s)');
ylabel('Channels with offset');
title(sprintf('Cleaned EEG trace: first %.0f seconds', plotSeconds));
grid on;
saveas(fig, fullfile(qcdir, '01_cleaned_trace_first60s.png'));
close(fig);

% Figure 2: channel RMS and peak-to-peak.
fig = figure('Visible', 'off', 'Position', [100 100 1200 650]);
tiledlayout(2,1);
nexttile;
bar(chanRMS);
ylabel('RMS (uV)');
title('Per-channel RMS');
grid on;
nexttile;
bar(chanPtP);
ylabel('Peak-to-peak (uV)');
xlabel('Channel');
title('Per-channel peak-to-peak');
grid on;
saveas(fig, fullfile(qcdir, '02_channel_amplitude_metrics.png'));
close(fig);

% Figure 3: PSD comparison between intermediate and final if possible.
fig = figure('Visible', 'off', 'Position', [100 100 1200 650]);
hold on;
if ~isempty(EEG_mid)
    midData = double(EEG_mid.data(1:min(size(EEG_mid.data,1), nChan), :));
    [pxxMid, fMid] = pwelch(midData', round(4*EEG_mid.srate), [], [], EEG_mid.srate);
    plot(fMid, 10*log10(median(pxxMid, 2, 'omitnan')), 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
end
[pxxFinal, fFinal] = pwelch(data', round(4*fs), [], [], fs);
plot(fFinal, 10*log10(median(pxxFinal, 2, 'omitnan')), 'b', 'LineWidth', 1.5);
xlim([0 80]);
xlabel('Frequency (Hz)');
ylabel('Median PSD across channels (dB)');
if ~isempty(EEG_mid)
    legend({'After FASTR/downsample/filter p-1', 'Final cleaned EEG'}, 'Location', 'best');
else
    legend({'Final cleaned EEG'}, 'Location', 'best');
end
title('Power spectrum QC');
grid on;
saveas(fig, fullfile(qcdir, '03_psd_comparison.png'));
close(fig);

% Figure 4: heart-rate QC from QRS file, if available.
qrsFile = fullfile(outdir, [cfg.run_id '_fMRIB_QRS.csv']);
if exist(qrsFile, 'file')
    qrs = readmatrix(qrsFile);
    qrs = qrs(:);
    qrs = qrs(isfinite(qrs));
    rr = diff(qrs) / fs;
    hr = 60 ./ rr;
    hr = hr(hr > 25 & hr < 180);
    fig = figure('Visible', 'off', 'Position', [100 100 1100 550]);
    histogram(hr, 40);
    xlabel('Heart rate (bpm)');
    ylabel('Count');
    title(sprintf('QRS-derived heart rate, median %.1f bpm', median(hr, 'omitnan')));
    grid on;
    saveas(fig, fullfile(qcdir, '04_qrs_heart_rate_histogram.png'));
    close(fig);
end

fprintf('QC complete. Files saved in:\n%s\n', qcdir);
