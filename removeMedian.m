function aMat = removeMedian(aMat, segLength)
% usage: matIn = removeMedian(aMat, segLength)
% function to remove the median from a vector or matrix. Runs along the
% first dimension. aMat is the data, 'segLength' defines smaller segments
% along which the median is removed. If seglength is not given, simply
% removes the median from each column of aMat.

matSize = size(aMat,1);
if ~exist('segLength', 'var') || isempty(segLength)
    segLength = matSize;
end


%%
for x = 0 : segLength : matSize
    if x + segLength < matSize
        aMat(x + (1:segLength), :) = aMat(x + (1:segLength), :) - nanmedian(aMat(x + (1:segLength), :));
    else
        aMat(x : end, :) = aMat(x : end, :) - nanmedian(aMat(x : end, :));
    end
end