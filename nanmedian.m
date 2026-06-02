function out = nanmedian(x, dim)
% NANMEDIAN Median ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps median(..., 'omitnan')
%
% Syntax:
%   y = nanmedian(x)           % median along first non-singleton dimension
%   y = nanmedian(x, dim)      % median along dimension dim
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - median value(s) with NaN values ignored

if nargin < 2
    out = median(x, 'omitnan');
else
    out = median(x, dim, 'omitnan');
end
end
