% Check whether the APPEAR-cleaned EEG is ready for ERP analysis.
% This script does not modify the cleaned EEG file.

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

final_file = cfg.final_eeg_file;
out_dir = cfg.erp_check_dir;

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

report_file = fullfile(out_dir, 'ERP_readiness_report.txt');
fid = fopen(report_file, 'w');
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, 'ERP readiness check: %s\n', cfg.run_id);
fprintf(fid, 'Generated: %s\n\n', datestr(now));
fprintf(fid, 'Final EEG file: %s\n', final_file);
fprintf(fid, 'Channels: %d\n', EEG.nbchan);
fprintf(fid, 'Samples: %d\n', EEG.pnts);
fprintf(fid, 'Sampling rate: %.3f Hz\n', EEG.srate);
fprintf(fid, 'Duration: %.2f s / %.2f min\n', EEG.pnts / EEG.srate, EEG.pnts / EEG.srate / 60);
fprintf(fid, 'Non-finite samples: %d\n\n', sum(~isfinite(EEG.data(:))));

if ~isfield(EEG, 'event') || isempty(EEG.event)
    fprintf(fid, 'No events found. ERP is NOT ready until stimulus onsets are imported.\n');
    disp(['ERP readiness report saved: ' report_file]);
    return;
end

event_types = cell(numel(EEG.event), 1);
event_latency_sec = nan(numel(EEG.event), 1);
for k = 1:numel(EEG.event)
    if isfield(EEG.event, 'type')
        event_types{k} = char(string(EEG.event(k).type));
    else
        event_types{k} = '';
    end
    if isfield(EEG.event, 'latency') && ~isempty(EEG.event(k).latency)
        event_latency_sec(k) = double(EEG.event(k).latency) / EEG.srate;
    end
end

[unique_types, ~, idx] = unique(event_types);
counts = accumarray(idx, 1);
[counts, order] = sort(counts, 'descend');
unique_types = unique_types(order);

fprintf(fid, 'Event types:\n');
for k = 1:numel(unique_types)
    fprintf(fid, '  %s: %d\n', unique_types{k}, counts(k));
end
fprintf(fid, '\n');

known_non_erp = {'R128', 'Sync On', 'qrs', 'boundary'};
is_candidate = true(size(unique_types));
for k = 1:numel(unique_types)
    is_candidate(k) = ~any(strcmpi(unique_types{k}, known_non_erp));
end
candidate_types = unique_types(is_candidate);

if isempty(candidate_types)
    fprintf(fid, 'ERP status: NOT READY\n');
    fprintf(fid, 'Reason: only scanner sync / QRS / boundary events were found.\n');
    fprintf(fid, 'Next needed input: stimulus/event onset log with event names and onset times.\n');
else
    fprintf(fid, 'ERP status: POSSIBLY READY\n');
    fprintf(fid, 'Candidate ERP event types:\n');
    for k = 1:numel(candidate_types)
        fprintf(fid, '  %s\n', candidate_types{k});
    end
end

T = table(event_latency_sec, event_types, 'VariableNames', {'latency_sec', 'event_type'});
writetable(T, fullfile(out_dir, 'event_table_all.csv'));

fig = figure('Visible', 'off', 'Position', [100 100 1400 450]);
hold on;
for k = 1:numel(unique_types)
    these = strcmp(event_types, unique_types{k});
    plot(event_latency_sec(these), k * ones(sum(these), 1), '.', 'MarkerSize', 10);
end
yticks(1:numel(unique_types));
yticklabels(unique_types);
xlabel('Time (s)');
ylabel('Event type');
title('Event timeline');
grid on;
saveas(fig, fullfile(out_dir, 'event_timeline.png'));
close(fig);

disp(['ERP readiness report saved: ' report_file]);
disp(['Event table saved: ' fullfile(out_dir, 'event_table_all.csv')]);
disp(['Event timeline saved: ' fullfile(out_dir, 'event_timeline.png')]);
