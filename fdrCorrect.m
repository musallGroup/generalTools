function [h, adj_p] = fdrCorrect(p, alpha)
% fdrCorrect - Benjamini-Hochberg false discovery rate correction
%
% INPUTS
%   p     : vector of p-values (NaN entries are ignored)
%   alpha : significance threshold (default 0.05)
%
% OUTPUTS
%   h     : logical vector, true for tests that survive FDR correction
%   adj_p : FDR-adjusted p-values (NaN where input was NaN)

if nargin < 2 || isempty(alpha)
    alpha = 0.05;
end

p = p(:);
n = numel(p);
h     = false(n, 1);
adj_p = nan(n, 1);

validMask = ~isnan(p);
pValid    = p(validMask);
nValid    = numel(pValid);
if nValid == 0, return; end

% sort and compute BH-adjusted p-values
[sortedP, sortIdx] = sort(pValid);
adjSorted = min(sortedP .* nValid ./ (1:nValid)', 1);

% enforce monotonicity (adjusted p-values must be non-decreasing)
for k = nValid-1:-1:1
    adjSorted(k) = min(adjSorted(k), adjSorted(k+1));
end

% map back to original order
adjValid           = nan(nValid, 1);
adjValid(sortIdx)  = adjSorted;
adj_p(validMask)   = adjValid;
h(validMask)       = adjValid <= alpha;

end
