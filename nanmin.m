function out = nanmin(x, varargin)
% NANMIN Minimum ignoring NaN values (MATLAB 2025 compatibility wrapper)
%   For MATLAB 2025+, wraps min(..., 'omitnan')
%
% Syntax:
%   y = nanmin(x)              % min along first non-singleton dimension
%   y = nanmin(x, dim)         % min along dimension dim
%   y = nanmin(x, [], dim)     % legacy toolbox form (equivalent to above)
%
% Input:
%   x    - numeric array
%   dim  - dimension (optional, defaults to first non-singleton)
%
% Output:
%   out  - minimum value(s) with NaN values ignored

if isempty(varargin)
    out = min(x, [], 'omitnan');
elseif numel(varargin) == 1
    dim = varargin{1};
    if isempty(dim)
        out = min(x, [], 'omitnan');
    else
        out = min(x, [], dim, 'omitnan');
    end
elseif numel(varargin) == 2
    % Legacy form nanmin(x, [], dim); second arg must be empty (no elementwise mode).
    if ~isempty(varargin{1})
        error('nanmin:tooManyInputs', ...
            'Elementwise nanmin(A, B) is not supported; use min(A, B, ''omitnan'') directly.');
    end
    dim = varargin{2};
    if isempty(dim)
        out = min(x, [], 'omitnan');
    else
        out = min(x, [], dim, 'omitnan');
    end
else
    error('nanmin:tooManyInputs', 'Too many input arguments.');
end
end
