function [mapImg, cRange] = imageScale(cMap, cRange, twoSided)
% quick command to plot image and set NaNs to be transparent. cRange
% defines a symmetric color range, based on top 'cRange' percentile in the image.
% 'twoSided' determines whether color range should be positive and negative
% (default) or only positive.
% usage: [mapImg, cRange] = imageScale(cMap, cRange, twoSided)

if ~exist('cRange', 'var') || isempty(cRange)
    cRange = abs(prctile(cMap(:),97.5));
end

if ~exist('twoSided', 'var')
    twoSided = true;
end

if twoSided
    cRange = [-cRange cRange];
else
    cRange = [prctile(cMap(:),2.5) prctile(cMap(:),97.5)];
end

mapImg = imshow(squeeze(cMap),cRange);
set(mapImg,'AlphaData',~isnan(mapImg.CData)); %make NaNs transparent.
