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
%   'SafeMove'  - true/false (default: false). Forces --maxSize 0 so every
%                 file classifies as MOVE-category, safely: serverTransfer.py
%                 (>= 1.0.4) handles this itself in a single pass via
%                 move_with_verify() - same-volume moves use an atomic
%                 os.rename() (no data ever re-read), and cross-volume moves
%                 copy, hash-verify against the source, and only then delete
%                 it (retrying once on a verification mismatch before giving
%                 up with the source left intact). Any --maxSize supplied by
%                 the caller is stripped with a warning, since SafeMove
%                 always forces 0. This used to require a manual two/three
%                 pass dance at this wrapper level (copy-only pass, then a
%                 separate verified-delete pass) because serverTransfer.py's
%                 MOVE handling used to call shutil.move() directly with no
%                 verification; that safety net now lives in the Python
%                 script itself, so SafeMove is just a single call here.
%
% Returns:
%   status - exit code from system()
%   cmdout - stdout/stderr from python
%   cmd    - the exact command executed (char)
%
% Examples:
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run --maxSize 100000');
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', {'--dry-run','--maxSize','100000'});
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run','--maxSize','100000');
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','E:\', '--dry-run', 'PythonExe','C:\Anaconda3\python.exe');
%   [st,out] = runServerTransfer('F:\BpodBehavior\427','\\naskampa\lts\', 'SafeMove', true);

% -----------------------------
% Parse MATLAB-only name-value options if present
% -----------------------------
pythonExe = 'python';
printCmd  = true;
safeMove  = false;

% Detect start of MATLAB-only name-value options without breaking forwarding.
% Supported keys: PythonExe, PrintCmd, SafeMove
nvIdx = [];
for i = 1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(strtrim(string(varargin{i})));
        if key == "pythonexe" || key == "printcmd" || key == "safemove"
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
        error('MATLAB options must be name-value pairs: PythonExe, PrintCmd, SafeMove.');
    end

    for k = 1:2:numel(nvArgs)
        name = lower(strtrim(string(nvArgs{k})));
        val  = nvArgs{k+1};
        switch name
            case "pythonexe"
                pythonExe = char(val);
            case "printcmd"
                printCmd = logical(val);
            case "safemove"
                safeMove = logical(val);
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
% Build the forwarded argument string. SafeMove forces --maxSize 0; every
% file then classifies as MOVE-category, which serverTransfer.py's
% move_with_verify() (>= 1.0.4) handles safely in a single pass on its own
% (see help text above).
% -----------------------------
if safeMove
    [tokens, nStripped] = stripFlagWithValue(toTokenList(forwardArgs), '--maxSize');
    if nStripped > 0
        warning('runServerTransfer:SafeMoveIgnoresMaxSize', ...
            '--maxSize is ignored when ''SafeMove'' is true (forced to 0).');
    end
    extra = joinTokens([tokens, {'--maxSize', '0'}]);
else
    extra = buildForwardArgString(forwardArgs);
end

[cmd, status, cmdout] = execTransfer(sourcePath, targetRoot, scriptPath, extra, pythonExe, printCmd, '');

if status ~= 0
    warning('serverTransfer.py returned non-zero exit status: %d', status);
end

end


% =======================================================================
% Helper: execTransfer
% =======================================================================
function [cmd, status, cmdout] = execTransfer(sourcePath, targetRoot, scriptPath, extra, pythonExe, printCmd, label)
% Build and run one serverTransfer.py invocation, returning the command,
% exit status, and captured stdout/stderr.
%
% Prefix with a cd so cmd.exe has a valid CWD even when MATLAB's working
% directory is a UNC path (cmd.exe cannot use UNC paths as CWD).
cmd = sprintf('cd /d "%%USERPROFILE%%" && %s "%s" "%s" --target-root %s %s', ...
    pythonExe, ...
    scriptPath, ...
    sourcePath, ...
    targetRoot, ...
    extra);

if printCmd
    if ~isempty(label)
        fprintf('\n%s\nExecuting:\n%s\n\n', label, cmd);
    else
        fprintf('\nExecuting:\n%s\n\n', cmd);
    end
end

[status, cmdout] = system(cmd, '-echo');

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
extra = joinTokens(toTokenList(forwardArgs));
end


% =======================================================================
% Helper: toTokenList
% =======================================================================
function tokens = toTokenList(forwardArgs)
% Normalize the 3 supported forwarding forms (single string / single cell
% array / multiple strings) into one flat cell array of unquoted tokens.

if isempty(forwardArgs)
    tokens = {};
    return
end

% Case 1: one argument that is a cell array -> token list
if numel(forwardArgs) == 1 && iscell(forwardArgs{1})
    tokens = cellfun(@char, forwardArgs{1}, 'UniformOutput', false);
    return
end

% Case 2: one argument that is a string/char -> SPLIT into tokens
if numel(forwardArgs) == 1 && (ischar(forwardArgs{1}) || isstring(forwardArgs{1}))
    s = strtrim(char(forwardArgs{1}));
    if isempty(s)
        tokens = {};
        return
    end
    tokens = splitCommandLinePreserveQuotes(s);
    return
end

% Case 3: multiple args -> each is a token
tokens = cellfun(@char, forwardArgs, 'UniformOutput', false);

end


% =======================================================================
% Helper: joinTokens
% =======================================================================
function extra = joinTokens(tokens)
% Quote each token as needed and join into the CLI argument string
% expected by execTransfer (leading space, or empty if no tokens).
if isempty(tokens)
    extra = '';
    return
end
extra = " " + strjoin(cellfun(@quoteToken, tokens, 'UniformOutput', false), " ");
extra = char(extra);
end


% =======================================================================
% Helper: stripFlagWithValue
% =======================================================================
function [tokens, nStripped] = stripFlagWithValue(tokens, flagName)
% Remove all occurrences of a flag AND the token immediately following it
% (its value), e.g. stripping '--maxSize' also drops the '50' after it.
nStripped = 0;
out = {};
i = 1;
while i <= numel(tokens)
    if strcmp(tokens{i}, flagName)
        nStripped = nStripped + 1;
        if i < numel(tokens)
            i = i + 2;  % skip flag + its value
        else
            i = i + 1;  % dangling flag with no value; just drop it
        end
    else
        out{end+1} = tokens{i}; %#ok<AGROW>
        i = i + 1;
    end
end
tokens = out;
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
