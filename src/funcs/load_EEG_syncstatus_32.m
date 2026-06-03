function [EEG,chlb,mrkA] = load_EEG_syncstatus_32(indir,infile,scntme,tr,slmkpertr)
% Load a BrainVision EEG-fMRI recording whose volume markers are stored as
% BrainVision "SyncStatus,Sync On" markers instead of APPEAR's expected R128.
%
% This local adapter keeps channels 1:32 only, matching APPEAR's original
% 31 EEG + ECG channel assumption for this subject. In this dataset channel
% 32 is ECG.

fprintf('Loading eeg data from %s/%s\n', indir, infile);
EEG = pop_loadbv(indir, strcat(infile, '.vhdr'));

if EEG.nbchan < 32
    error('Expected at least 32 channels, found %d.', EEG.nbchan);
end

% APPEAR's bundled helper functions assume 32 channels with ECG last.
EEG.data = EEG.data(1:32, :);
EEG.nbchan = 32;
if isfield(EEG, 'chanlocs') && numel(EEG.chanlocs) >= 32
    EEG.chanlocs = EEG.chanlocs(1:32);
end

srate = EEG.srate;
expectedStep = round(tr * srate);
tol = max(5, round(0.02 * expectedStep));

evt = EEG.event;
lat = [];
for ii = 1:numel(evt)
    typ = '';
    if isfield(evt(ii), 'type') && ~isempty(evt(ii).type)
        typ = char(evt(ii).type);
    end
    if strcmpi(typ, 'R128') || strcmpi(typ, 'SyncStatus') || strcmpi(typ, 'Sync On') || contains(lower(typ), 'sync')
        lat(end+1) = round(evt(ii).latency); %#ok<AGROW>
    end
end
lat = unique(sort(lat));

if isempty(lat)
    error('No SyncStatus/R128 markers found in %s.vmrk.', infile);
end

% Find the first marker in the longest stable TR-spaced run. The subject1
% file starts with two short-spaced SyncStatus markers, then stable TR marks.
startIdx = 1;
if numel(lat) >= 6
    for ii = 1:(numel(lat)-5)
        if all(abs(diff(lat(ii:ii+5)) - expectedStep) <= tol)
            startIdx = ii;
            break;
        end
    end
end

if isempty(scntme) || scntme <= 0
    nTR = numel(lat) - startIdx + 1;
    scntme = nTR * tr;
else
    nTR = min(floor(scntme / tr), numel(lat) - startIdx + 1);
end

mrkA = lat(startIdx:(startIdx+nTR-1));

% Keep only markers that are followed by a complete TR worth of EEG samples.
% Some BrainVision recordings contain a final sync marker near the file end,
% but not enough samples after it for FASTR/APPEAR to crop a full volume.
completeMask = (mrkA + expectedStep - 1) <= EEG.pnts;
if any(~completeMask)
    fprintf('Dropping %d trailing incomplete TR marker(s) near the file end.\n', sum(~completeMask));
end
mrkA = mrkA(completeMask);
scntme = numel(mrkA) * tr;

% Add R128-like events so fMRIB/FASTR functions can still find a conventional
% marker type if they inspect EEG.event internally.
EEG.event = AddMarker(EEG.event, mrkA, 1, 0, 'R128', 'Response');
EEG.event = sortlatency(EEG.event, 1);

chlb = chlin();
EEG.bad = [];
EEG.badmot = [];
EEG.APPEAR.TR = tr;
EEG.APPEAR.slice_per_TR = slmkpertr;
EEG.APPEAR.scntme = scntme;
EEG.APPEAR.chlb = chlb;
EEG.APPEAR.mrkA = mrkA;

fprintf('Detected %d stable TR markers. First=%d, last=%d, inferred scan=%.1f s.\n', numel(mrkA), mrkA(1), mrkA(end), scntme);
end
