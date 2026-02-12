function [status, cmdout, cmd] = runServerTransfer(sourcePath, targetRoot, varargin)
% runServerTransfer
%
% MATLAB wrapper for serverTransfer.py that preserves full CLI functionality.
% It locates serverTransfer.py via which() and forwards ALL extra arguments
% directly to the Python script.
%
% Required:
%   sourcePath  - e.g. 'F:\BpodBehavior\427'
%   targetRoot  - e.g. 'E:\' or '\\naskampa\lts\'
%
% Optional (forwarded to Python):
%   Any additional CLI flags supported by serverTransfer.py, provided as:
%     (A) a single string (will be tokenized!)
%         runServerTransfer(src, tgt, '--dry-run --maxSize 100000')
%     (B) a cell array of tokens
%         runServerTransfer(src, tgt, {'--dry-run','--maxSize','100000'})
%     (C) multiple strings/tokens
%         runServerTransfer(src, tgt, '--dry-run', '--maxSize', '100000')
%
% Optional MATLAB-only name-value options (must come LAST):
%   'PythonExe' - python executable or full path (default: 'python')
%   'PrintCmd'  - true/false, print the constructed command (default: true)
%
% Returns:
%   status - exit code from system()
%   cmdout - stdout/stderr from python
%   cmd    - the exact command executed
%
% Examples:
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run --maxSize 100000');
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', {'--dry-run','--maxSize','100000'});
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run','--maxSize','100000');
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run', 'PythonExe','C:\Anaconda3\python.exe');

% -----------------------------
% Parse MATLAB-only name-value options if present
% -----------------------------
pythonExe = 'python';
printCmd  = true;

% Detect start of MATLAB-only name-value options without breaking forwarding.
% Supported keys: PythonExe, PrintCmd
nvIdx = [];
for i = 1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(strtrim(string(varargin{i})));
        if key == "pythonexe" || key == "printcmd"
            nvIdx = i;
            break
        end
    end
end

forwardArgs = varargin;

if ~isempty(nvIdx)
    forwardArgs = varargin(1:nvIdx-1);
    nvArgs = varargin(nvIdx:end);

    if mod(numel(nvArgs),2) ~= 0
        error('MATLAB options must be name-value pairs: PythonExe, PrintCmd.');
    end

    for k = 1:2:numel(nvArgs)
        name = lower(strtrim(string(nvArgs{k})));
        val  = nvArgs{k+1};
        switch name
            case "pythonexe"
                pythonExe = char(val);
            case "printcmd"
                printCmd = logical(val);
            otherwise
                error('Unknown MATLAB option: %s', name);
        end
    end
end

sourcePath = char(sourcePath);
targetRoot = char(targetRoot);

% -----------------------------
% Locate serverTransfer.py using which()
% -----------------------------
scriptPath = which('serverTransfer.py');
if isempty(scriptPath)
    error('Could not find serverTransfer.py using which(). Make sure it is on the MATLAB path.');
end

% -----------------------------
% Build forwarded arguments string
% -----------------------------
extra = buildForwardArgString(forwardArgs);

% -----------------------------
% Build final command
% -----------------------------
% Note: we do NOT quote the entire extra string; it is appended as tokens.
cmd = sprintf('%s "%s" "%s" --target-root %s %s', ...
    pythonExe, ...
    scriptPath, ...
    sourcePath, ...
    targetRoot, ...
    extra);

if printCmd
    fprintf('\nExecuting:\n%s\n\n', cmd);
end

% -----------------------------
% Execute
% -----------------------------
[status, cmdout] = system(cmd);

fprintf('%s\n', cmdout);

if status ~= 0
    warning('serverTransfer.py returned non-zero exit status: %d', status);
end

end


% =======================================================================
% Helper: buildForwardArgString
% =======================================================================
function extra = buildForwardArgString(forwardArgs)
% Build a properly tokenized CLI argument string.
% Key behavior:
% - If forwardArgs is ONE string like '--dry-run --maxSize 100000', it will
%   be split into tokens so argparse sees separate args.
% - If forwardArgs is a cell array, it is treated as tokens already.
% - If forwardArgs is multiple strings, each is treated as a token.

if isempty(forwardArgs)
    extra = "";
    return
end

% Case 1: one argument that is a cell array -> token list
if numel(forwardArgs) == 1 && iscell(forwardArgs{1})
    tokens = forwardArgs{1};
    tokens = cellfun(@char, tokens, 'UniformOutput', false);
    extra = " " + strjoin(cellfun(@quoteToken, tokens, 'UniformOutput', false), " ");
    extra = char(extra);
    return
end

% Case 2: one argument that is a string/char -> SPLIT into tokens
if numel(forwardArgs) == 1 && (ischar(forwardArgs{1}) || isstring(forwardArgs{1}))
    s = strtrim(char(forwardArgs{1}));
    if isempty(s)
        extra = "";
        return
    end
    tokens = splitCommandLinePreserveQuotes(s);
    extra = " " + strjoin(cellfun(@quoteToken, tokens, 'UniformOutput', false), " ");
    extra = char(extra);
    return
end

% Case 3: multiple args -> each is a token
tokens = cellfun(@char, forwardArgs, 'UniformOutput', false);
extra = " " + strjoin(cellfun(@quoteToken, tokens, 'UniformOutput', false), " ");
extra = char(extra);

end


% =======================================================================
% Helper: splitCommandLinePreserveQuotes
% =======================================================================
function tokens = splitCommandLinePreserveQuotes(s)
% Split a command-line string into tokens, preserving quoted substrings.
% Supports "double quotes" around tokens with spaces.
%
% Example:
%   --move-keyword "raw video" --dry-run
% -> {'--move-keyword','raw video','--dry-run'}

tokens = {};
i = 1;
n = length(s);

while i <= n
    % skip whitespace
    while i <= n && isspace(s(i))
        i = i + 1;
    end
    if i > n
        break
    end

    if s(i) == '"'
        % quoted token
        i = i + 1;
        start = i;
        while i <= n && s(i) ~= '"'
            i = i + 1;
        end
        tokens{end+1} = s(start:i-1); %#ok<AGROW>
        if i <= n && s(i) == '"'
            i = i + 1; % skip closing quote
        end
    else
        % unquoted token
        start = i;
        while i <= n && ~isspace(s(i))
            i = i + 1;
        end
        tokens{end+1} = s(start:i-1); %#ok<AGROW>
    end
end

end


% =======================================================================
% Helper: quoteToken
% =======================================================================
function t = quoteToken(tok)
% Quote a token if it contains spaces or common special characters that can
% break CLI parsing. Also escape embedded quotes.

tok = char(tok);
if isempty(tok)
    t = '""';
    return
end

needsQuote = contains(tok, ' ') || contains(tok, '"') || ...
             contains(tok, '&') || contains(tok, '(') || contains(tok, ')');

tok = strrep(tok, '"', '\"');

if needsQuote
    t = ['"' tok '"'];
else
    t = tok;
end

end
