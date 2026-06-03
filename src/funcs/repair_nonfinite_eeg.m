function [data, nBad] = repair_nonfinite_eeg(data)
% Replace NaN/Inf samples channel-wise before ICA.

nBad = sum(~isfinite(data(:)));
if nBad == 0
    return;
end

fprintf('Repairing %d non-finite EEG samples before ICA...\n', nBad);

for ch = 1:size(data, 1)
    x = double(data(ch, :));
    good = isfinite(x);
    if all(good)
        continue;
    end
    if sum(good) < 2
        x(~good) = 0;
    else
        idx = 1:numel(x);
        x(~good) = interp1(idx(good), x(good), idx(~good), 'linear', 'extrap');
    end
    data(ch, :) = x;
end
end
