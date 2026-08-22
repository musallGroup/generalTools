function p = adjustCaxis(cRange)
% adjustCaxis  Set symmetric caxis from image data percentile.
%   adjustCaxis(cRange) finds the image in the current axes, computes
%   prctile(abs(data), cRange) ignoring NaNs, and sets caxis to
%   [-p, p]. Prints the new range if applied.
%   p = adjustCaxis(cRange) also returns the applied percentile value.

p   = NaN;
ax  = gca;
img = findobj(ax, 'Type', 'image');
if isempty(img)
    return;
end

data = get(img(1), 'CData');
p    = prctile(abs(data(~isnan(data))), cRange);
if p > 0
    caxis(ax, [-p, p]);
    fprintf('adjustCaxis: caxis set to [%.4g, %.4g] (p%d)\n', -p, p, round(cRange));
end
