function out = nansum(x, dim)
% NANSUM Sum ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps sum(..., 'omitnan')
%
% Syntax:
%   y = nansum(x)           % sum along first non-singleton dimension
%   y = nansum(x, dim)      % sum along dimension dim
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - sum value(s) with NaN values ignored

if nargin < 2
    out = sum(x, 'omitnan');
else
    out = sum(x, dim, 'omitnan');
end
end
