clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
cfg = project_config();

fprintf('Checking APPEAR runtime requirements...\n\n');

fprintf('MATLAB version:\n');
disp(version);

fprintf('\nSignal Processing Toolbox license test:\n');
disp(license('test', 'Signal_Toolbox'));

fprintf('\nInstalled Signal Processing Toolbox metadata:\n');
disp(ver('signal'));

requiredFunctions = {'firls', 'butter', 'filtfilt', 'fir1', 'resample'};
fprintf('\nRequired function locations:\n');
missing = {};
for ii = 1:numel(requiredFunctions)
    fn = requiredFunctions{ii};
    loc = which(fn);
    if isempty(loc)
        fprintf('  MISSING: %s\n', fn);
        missing{end+1} = fn; %#ok<SAGROW>
    else
        fprintf('  OK: %s -> %s\n', fn, loc);
    end
end

fprintf('\nAPPEAR/EEGLAB function locations:\n');
if ~exist(cfg.appear_dir, 'dir')
    fprintf('  APPEAR folder not found: %s\n', cfg.appear_dir);
else
    cd(cfg.appear_dir);
    addpath(fullfile(cfg.appear_dir, 'funcs'));
    addpath(fullfile(cfg.appear_dir, 'eeglab2019_0'));
    addpath(fullfile(cfg.appear_dir, 'eeglab2019_0', 'plugins', 'bva-io1.5.13'));
    addpath(genpath(fullfile(cfg.appear_dir, 'eeglab2019_0', 'plugins', 'fMRIb2.00')));
end
fprintf('  pop_loadbv -> %s\n', which('pop_loadbv'));
fprintf('  pop_fmrib_fastr -> %s\n', which('pop_fmrib_fastr'));

if isempty(missing)
    fprintf('\nREADY: APPEAR dependencies look available.\n');
else
    fprintf('\nNOT READY: install MATLAB Signal Processing Toolbox before running APPEAR.\n');
end
