function out = nanstd(x, w, dim)
% NANSTD Standard deviation ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps std(..., 'omitnan')
%
% Syntax:
%   y = nanstd(x)              % std along first non-singleton dimension
%   y = nanstd(x, w)           % std with weight w (0=N-1, 1=N), along first non-singleton dim
%   y = nanstd(x, w, dim)      % std along dimension dim
%
% Input:
%   x    - numeric array
%   w    - weight (0 for N-1 normalization, 1 for N); defaults to 0
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - standard deviation with NaN values ignored

if nargin < 2 || isempty(w)
    out = std(x, 'omitnan');
elseif nargin < 3
    out = std(x, w, 'omitnan');
else
    out = std(x, w, dim, 'omitnan');
end
end
