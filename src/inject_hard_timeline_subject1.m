% Inject synthetic task events using a fixed 300-s hard timeline.
% It does not overwrite the original APPEAR output.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

final_file = cfg.final_eeg_file;
out_dir = cfg.hard_timeline_dir;

% ---- User-adjustable alignment settings ----
% The first video onset is assumed to be aligned to the visible event at 8.004 s.
first_video_onset_sec = cfg.first_video_onset_sec;

% Paradigm: 8 s blank + 48 * (3 s video + 3 s blank) + 4 s blank = 300 s.
initial_blank_sec = 8;
video_sec = 3;
post_video_blank_sec = 3;
trials_per_block = 48;
final_blank_sec = 4;

% Use only complete 300-s blocks by default. Set include_partial_last_block=true
% if you later confirm the final incomplete block should be kept.
include_partial_last_block = cfg.include_partial_last_block;

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

S = load(final_file);
if isfield(S, 'finalEEG')
    EEG = S.finalEEG;
elseif isfield(S, 'EEG')
    EEG = S.EEG;
else
    names = fieldnames(S);
    EEG = S.(names{1});
end

block_sec = initial_blank_sec + trials_per_block * (video_sec + post_video_blank_sec) + final_blank_sec;
block_start_sec = first_video_onset_sec - initial_blank_sec;
duration_sec = EEG.pnts / EEG.srate;

n_complete_blocks = floor((duration_sec - block_start_sec) / block_sec);
if include_partial_last_block
    n_blocks = ceil((duration_sec - block_start_sec) / block_sec);
else
    n_blocks = n_complete_blocks;
end

if n_blocks < 1
    error('No complete task block fits inside the EEG duration. Check first_video_onset_sec.');
end

orig_n_events = numel(EEG.event);
new_events = struct('type', {}, 'latency', {}, 'duration', {}, 'code', {});
row_block = [];
row_trial = [];
row_type = {};
row_onset_sec = [];
row_latency_sample = [];

event_i = 0;
for b = 1:n_blocks
    this_block_start = block_start_sec + (b - 1) * block_sec;
    this_block_end = this_block_start + block_sec;

    if this_block_start >= duration_sec
        continue;
    end

    event_i = event_i + 1;
    new_events(event_i).type = 'hard_block_start';
    new_events(event_i).latency = round(this_block_start * EEG.srate);
    new_events(event_i).duration = 0;
    new_events(event_i).code = 'hard_block_start';

    row_block(end+1, 1) = b;
    row_trial(end+1, 1) = 0;
    row_type{end+1, 1} = 'hard_block_start';
    row_onset_sec(end+1, 1) = this_block_start;
    row_latency_sample(end+1, 1) = new_events(event_i).latency;

    for t = 1:trials_per_block
        video_onset = this_block_start + initial_blank_sec + (t - 1) * (video_sec + post_video_blank_sec);
        video_offset = video_onset + video_sec;

        if video_onset >= duration_sec
            continue;
        end

        event_i = event_i + 1;
        new_events(event_i).type = 'hard_video_onset';
        new_events(event_i).latency = round(video_onset * EEG.srate);
        new_events(event_i).duration = round(video_sec * EEG.srate);
        new_events(event_i).code = sprintf('block%02d_trial%02d_video_onset', b, t);

        row_block(end+1, 1) = b;
        row_trial(end+1, 1) = t;
        row_type{end+1, 1} = 'hard_video_onset';
        row_onset_sec(end+1, 1) = video_onset;
        row_latency_sample(end+1, 1) = new_events(event_i).latency;

        if video_offset < duration_sec
            event_i = event_i + 1;
            new_events(event_i).type = 'hard_video_offset';
            new_events(event_i).latency = round(video_offset * EEG.srate);
            new_events(event_i).duration = 0;
            new_events(event_i).code = sprintf('block%02d_trial%02d_video_offset', b, t);

            row_block(end+1, 1) = b;
            row_trial(end+1, 1) = t;
            row_type{end+1, 1} = 'hard_video_offset';
            row_onset_sec(end+1, 1) = video_offset;
            row_latency_sample(end+1, 1) = new_events(event_i).latency;
        end
    end

    if this_block_end < duration_sec
        event_i = event_i + 1;
        new_events(event_i).type = 'hard_block_end';
        new_events(event_i).latency = round(this_block_end * EEG.srate);
        new_events(event_i).duration = 0;
        new_events(event_i).code = 'hard_block_end';

        row_block(end+1, 1) = b;
        row_trial(end+1, 1) = 0;
        row_type{end+1, 1} = 'hard_block_end';
        row_onset_sec(end+1, 1) = this_block_end;
        row_latency_sample(end+1, 1) = new_events(event_i).latency;
    end
end

orig_events = EEG.event(:)';
all_fields = unique([fieldnames(orig_events); fieldnames(new_events)]);
for f = 1:numel(all_fields)
    fname = all_fields{f};
    if ~isfield(orig_events, fname)
        for k = 1:numel(orig_events)
            orig_events(k).(fname) = [];
        end
    end
    if ~isfield(new_events, fname)
        for k = 1:numel(new_events)
            new_events(k).(fname) = [];
        end
    end
end

EEG.event = [orig_events new_events(:)'];
[~, order] = sort([EEG.event.latency]);
EEG.event = EEG.event(order);

if exist('eeg_checkset', 'file') == 2
    EEG = eeg_checkset(EEG, 'eventconsistency');
end

finalEEG_hardtimeline = EEG;
save(cfg.hard_timeline_eeg_file, 'finalEEG_hardtimeline', '-v7.3');

T = table(row_block, row_trial, row_type, row_onset_sec, row_latency_sample, ...
    'VariableNames', {'block', 'trial', 'event_type', 'onset_sec', 'latency_sample'});
writetable(T, fullfile(out_dir, 'hard_timeline_events.csv'));

report_file = fullfile(out_dir, 'hard_timeline_report.txt');
fid = fopen(report_file, 'w');
fprintf(fid, 'Hard timeline injection report\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'Input final EEG: %s\n', final_file);
fprintf(fid, 'Output EEG: %s\n', cfg.hard_timeline_eeg_file);
fprintf(fid, 'Duration: %.3f s\n', duration_sec);
fprintf(fid, 'First video onset anchor: %.3f s\n', first_video_onset_sec);
fprintf(fid, 'Block start inferred from anchor: %.3f s\n', block_start_sec);
fprintf(fid, 'Block duration: %.3f s\n', block_sec);
fprintf(fid, 'Complete blocks detected: %d\n', n_complete_blocks);
fprintf(fid, 'Blocks injected: %d\n', n_blocks);
fprintf(fid, 'Original events: %d\n', orig_n_events);
fprintf(fid, 'Synthetic events added: %d\n', numel(new_events));
fprintf(fid, 'Video onset events added: %d\n', sum(strcmp(row_type, 'hard_video_onset')));
fprintf(fid, 'Include partial final block: %d\n', include_partial_last_block);
if ~include_partial_last_block
    leftover = duration_sec - (block_start_sec + n_complete_blocks * block_sec);
    fprintf(fid, 'Unused tail after last complete block: %.3f s\n', leftover);
end
fclose(fid);

fig = figure('Visible', 'off', 'Position', [100 100 1400 450]);
video_rows = strcmp(row_type, 'hard_video_onset');
plot(row_onset_sec(video_rows), row_block(video_rows), '.k', 'MarkerSize', 10);
xlabel('Time (s)');
ylabel('Block');
title('Synthetic video onset timeline');
grid on;
saveas(fig, fullfile(out_dir, 'hard_timeline_video_onsets.png'));
close(fig);

disp(['Hard timeline report saved: ' report_file]);
disp(['Hard timeline event table saved: ' fullfile(out_dir, 'hard_timeline_events.csv')]);
disp(['Hard-timeline EEG saved: ' cfg.hard_timeline_eeg_file]);
