function cfg = project_config()
%PROJECT_CONFIG Central configuration for the EEGERP_test pipeline.
%
% Expected project layout:
%   EEGERP_test/
%     data/subject1/20260126_sub1_run1.vhdr/.vmrk/.eeg
%     external/appear/        % APPEAR repository or extracted source
%     outputs/                % generated outputs, ignored by git
%     src/                    % scripts in this repository

cfg.src_dir = fileparts(mfilename('fullpath'));
cfg.project_root = fileparts(cfg.src_dir);

cfg.data_root = fullfile(cfg.project_root, 'data');
cfg.output_root = fullfile(cfg.project_root, 'outputs');
cfg.external_root = fullfile(cfg.project_root, 'external');
cfg.appear_dir = fullfile(cfg.external_root, 'appear');

cfg.subject_id = 'subject1';
cfg.run_id = 'subject1_run1';
cfg.eeg_file_stem = '20260126_sub1_run1';
cfg.subject_data_dir = fullfile(cfg.data_root, cfg.subject_id);
cfg.subject_out_dir = fullfile(cfg.output_root, [cfg.run_id '_APPEAR']);

cfg.final_eeg_file = fullfile(cfg.subject_out_dir, [cfg.run_id '_finalEEG.mat']);
cfg.erp_check_dir = fullfile(cfg.subject_out_dir, 'ERP_check');
cfg.hard_timeline_dir = fullfile(cfg.subject_out_dir, 'hard_timeline');
cfg.hard_timeline_eeg_file = fullfile(cfg.hard_timeline_dir, [cfg.run_id '_finalEEG_hardtimeline.mat']);
cfg.erp_attempt_dir = fullfile(cfg.subject_out_dir, 'ERP_attempt_v3');

% Synthetic timeline settings. Change this value to test nearby anchors.
cfg.first_video_onset_sec = 8.004;
cfg.include_partial_last_block = false;

% APPEAR settings used in this first-pass test.
cfg.TR = 2;
cfg.slice_per_TR = 37; % TODO: verify from fMRI JSON/DICOM/scanner protocol.
cfg.ECG_channel_index = 32;
cfg.filter_range = [0.1 70];
cfg.output_srate = 250;
end
