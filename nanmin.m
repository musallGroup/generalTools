function out = nanmin(x, dim)
% NANMIN Minimum ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps min(..., 'omitnan')
%
% Syntax:
%   y = nanmin(x)           % min along first non-singleton dimension
%   y = nanmin(x, dim)      % min along dimension dim
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - minimum value(s) with NaN values ignored

if nargin < 2
    out = min(x, [], 'omitnan');
else
    out = min(x, [], dim, 'omitnan');
end
end
