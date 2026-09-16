function out = nanmax(x, varargin)
% NANMAX Maximum ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps max(..., 'omitnan')
%
% Syntax:
%   y = nanmax(x)              % max along first non-singleton dimension
%   y = nanmax(x, dim)         % max along dimension dim
%   y = nanmax(x, [], dim)     % legacy toolbox form (equivalent to above)
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - maximum value(s) with NaN values ignored

if isempty(varargin)
    out = max(x, [], 'omitnan');
elseif numel(varargin) == 1
    dim = varargin{1};
    if isempty(dim)
        out = max(x, [], 'omitnan');
    else
        out = max(x, [], dim, 'omitnan');
    end
elseif numel(varargin) == 2
    % Legacy form nanmax(x, [], dim); second arg must be empty (no elementwise mode).
    if ~isempty(varargin{1})
        error('nanmax:tooManyInputs', ...
            'Elementwise nanmax(A, B) is not supported; use max(A, B, ''omitnan'') directly.');
    end
    dim = varargin{2};
    if isempty(dim)
        out = max(x, [], 'omitnan');
    else
        out = max(x, [], dim, 'omitnan');
    end
else
    error('nanmax:tooManyInputs', 'Too many input arguments.');
end
end
