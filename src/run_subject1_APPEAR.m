clear; clc;

% Run this file from MATLAB:
%   cd('<path-to-EEGERP_test>/src')
%   run('run_subject1_APPEAR.m')

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
addpath(fullfile(script_dir, 'funcs'));
cfg = project_config();

if ~exist(cfg.appear_dir, 'dir')
    error('APPEAR not found. Put APPEAR source in: %s', cfg.appear_dir);
end

cd(cfg.appear_dir);
addpath(fullfile(cfg.appear_dir, 'funcs'));
addpath(fullfile(cfg.appear_dir, 'eeglab2019_0'));
addpath(fullfile(cfg.appear_dir, 'eeglab2019_0', 'plugins', 'bva-io1.5.13'));
addpath(genpath(fullfile(cfg.appear_dir, 'eeglab2019_0', 'plugins', 'fMRIb2.00')));
[ALLEEG, ~, ~, ~] = eeglab('nogui'); %#ok<ASGLU>
close all;

sub_folder = [cfg.subject_data_dir filesep];
subj_eeg_file = cfg.eeg_file_stem;

subj_out_folder = cfg.subject_out_dir;
if ~exist(subj_out_folder, 'dir')
    mkdir(subj_out_folder);
end

TR = cfg.TR;                         % seconds; verify from fMRI metadata
slice_per_TR = cfg.slice_per_TR;      % TODO: replace with actual fMRI slice count
scntme = [];            % empty = infer scan length from stable TR markers

[EEG] = load_EEG_syncstatus_32(sub_folder, subj_eeg_file, scntme, TR, slice_per_TR);
EEG.chanlocs = loadbvef('BC-MR-32.bvef');

EEG.APPEAR.Fs = cfg.output_srate;        % output sampling rate for ERP
EEG.APPEAR.filterRange = cfg.filter_range;
EEG.APPEAR.BCG_Crorrection = 'fMRIB';   % use ECG channel QRS detection
EEG.APPEAR.ECG_ch_ind = cfg.ECG_channel_index;
EEG.APPEAR.polt_ecg_range = [5 35];     % QA plot window in seconds

finalEEG = APPEAR(EEG, subj_out_folder, cfg.run_id);
save(cfg.final_eeg_file, 'finalEEG', '-v7.3');

fprintf('\nDone. Cleaned EEG saved in:\n%s\n', subj_out_folder);
