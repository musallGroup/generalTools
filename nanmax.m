function out = nanmax(x, dim)
% NANMAX Maximum ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps max(..., 'omitnan')
%
% Syntax:
%   y = nanmax(x)           % max along first non-singleton dimension
%   y = nanmax(x, dim)      % max along dimension dim
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - maximum value(s) with NaN values ignored

if nargin < 2
    out = max(x, [], 'omitnan');
else
    out = max(x, [], dim, 'omitnan');
end
end
