function peaks = clean_peak_train(peaks, fs, minRRsec, maxRRsec)
% Remove duplicate and physiologically implausible cardiac peak detections.

if isempty(peaks)
    return;
end

peaks = unique(round(peaks(:)'));
minRR = round(minRRsec * fs);
maxRR = round(maxRRsec * fs);

cleaned = peaks(1);
for ii = 2:numel(peaks)
    rr = peaks(ii) - cleaned(end);
    if rr < minRR
        continue;
    end
    cleaned(end+1) = peaks(ii); %#ok<AGROW>
end

if nargin >= 4 && ~isempty(maxRRsec) && maxRRsec > 0 && numel(cleaned) > 2
    rr = diff(cleaned);
    keep = [true, rr <= maxRR];
    % Keep isolated long gaps if removing them would collapse the train too
    % aggressively; APPEAR/fMRIB can tolerate occasional missed beats better
    % than duplicate peaks.
    if sum(keep) > 0.75 * numel(cleaned)
        cleaned = cleaned(keep);
    end
end

peaks = cleaned;
end
