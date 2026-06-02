function out = nanmean(x, dim)
% NANMEAN Mean ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps mean(..., 'omitnan')
%
% Syntax:
%   y = nanmean(x)           % mean along first non-singleton dimension
%   y = nanmean(x, dim)      % mean along dimension dim
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - mean value(s) with NaN values ignored

if nargin < 2
    out = mean(x, 'omitnan');
else
    out = mean(x, dim, 'omitnan');
end
end
