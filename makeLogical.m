function vecOut = makeLogical(cIdx, vecLength)
% function to create a logical vector of length 'vecLength' from index cIdx

vecOut = false(vecLength, 1);
cIdx = cIdx(~isnan(cIdx) & cIdx <= vecLength);
vecOut(cIdx(~isnan(cIdx))) = true;
