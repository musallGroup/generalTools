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
%   'SafeMove'  - true/false (default: false). Runs the two-pass
%                 copy-then-verified-delete pattern instead of a single
%                 call, so source files are only ever deleted after their
%                 copy on the target has been hash-verified:
%                   Pass 1 (dry-run check): forces a very large --maxSize
%                     so every file classifies as COPY, and confirms
%                     nothing would be MOVEd (moved=0, errors=0) before
%                     any data is touched.
%                   Pass 1 (live): re-runs the same COPY-only transfer for
%                     real. Source is left untouched.
%                   Pass 2 (live): re-runs with --maxSize 0, so every file
%                     now hits serverTransfer.py's "dst already exists"
%                     branch, which deletes the source only after a
%                     partial blake2b hash match against the target.
%                 --maxSize is meaningless under SafeMove (Pass 1/Pass 2
%                 each set it internally) and is stripped from the
%                 forwarded args with a warning if supplied. If --dry-run
%                 is also given, only the Pass 1 safety check is run and
%                 reported; nothing is copied, moved, or deleted.
%
% Returns:
%   status - exit code from system() (default mode); under SafeMove, -1 if
%            the Pass 1 safety check failed, otherwise the exit code of
%            the last pass that ran
%   cmdout - stdout/stderr from python (default mode); under SafeMove, the
%            concatenated output of every pass that ran, each under a
%            "===== SafeMove ... =====" header
%   cmd    - the exact command executed (default mode, char); under
%            SafeMove, a cell array of the command(s) executed, in order
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
% Default (single-pass) mode: unchanged behavior
% -----------------------------
if ~safeMove
    extra = buildForwardArgString(forwardArgs);
    [cmd, status, cmdout] = execTransfer(sourcePath, targetRoot, scriptPath, extra, pythonExe, printCmd, '');

    if status ~= 0
        warning('serverTransfer.py returned non-zero exit status: %d', status);
    end
    return
end

% -----------------------------
% SafeMove mode: two-pass copy-then-verified-delete
% (see [[project_serverDataStorage]] / vault "Server Management - BRAIN lab"
% for why a single-pass move is not used: shutil.move copies then deletes
% with no integrity check on that specific copy before the source is gone)
% -----------------------------
tokens = toTokenList(forwardArgs);

[tokens, nStripped] = stripFlagWithValue(tokens, '--maxSize');
if nStripped > 0
    warning('runServerTransfer:SafeMoveIgnoresMaxSize', ...
        '--maxSize is ignored when ''SafeMove'' is true (Pass 1 uses a large fixed value, Pass 2 uses 0).');
end

userWantsDryRunOnly = hasFlag(tokens, '--dry-run');
tokens = removeFlag(tokens, '--dry-run');

HUGE_MAXSIZE = '100000';  % GB - larger than any realistic single file; forces COPY-only in Pass 1

% ---- Pass 1 dry-run: confirm HUGE_MAXSIZE is large enough that nothing gets MOVEd ----
step1DryExtra = joinTokens([tokens, {'--maxSize', HUGE_MAXSIZE, '--dry-run'}]);
[cmd1, status1, out1] = execTransfer(sourcePath, targetRoot, scriptPath, step1DryExtra, pythonExe, printCmd, ...
    'SafeMove Pass 1/2 (dry-run check)');
[moved1, errors1] = parseTransferSummary(out1);

if status1 ~= 0 || isnan(moved1) || isnan(errors1) || errors1 > 0 || moved1 > 0
    warning('runServerTransfer:SafeMoveCheckFailed', ...
        ['SafeMove Pass 1 dry-run check failed (exit=%d, moved=%d, errors=%d). Nothing was copied, moved, ' ...
         'or deleted. moved>0 means some files still classify as MOVE (e.g. via --move-ext/--move-keyword, ' ...
         'or a file bigger than %s GB) - remove those flags or investigate before retrying SafeMove.'], ...
        status1, moved1, errors1, HUGE_MAXSIZE);
    status = -1;
    cmdout = sprintf('===== SafeMove Pass 1/2 (dry-run check) =====\n%s', out1);
    cmd = {cmd1};
    return
end

if userWantsDryRunOnly
    fprintf('\nSafeMove preview OK: Pass 1 would COPY all files (moved=0, errors=0). Re-run without --dry-run to execute the safe move.\n');
    status = 0;
    cmdout = sprintf('===== SafeMove Pass 1/2 (dry-run check) =====\n%s', out1);
    cmd = {cmd1};
    return
end

% ---- Pass 1 live: copy everything; source untouched ----
step1LiveExtra = joinTokens([tokens, {'--maxSize', HUGE_MAXSIZE}]);
[cmd2, status2, out2] = execTransfer(sourcePath, targetRoot, scriptPath, step1LiveExtra, pythonExe, printCmd, ...
    'SafeMove Pass 1/2 (copy)');
cmdout = [sprintf('===== SafeMove Pass 1/2 (dry-run check) =====\n%s', out1), ...
          sprintf('\n===== SafeMove Pass 1/2 (copy) =====\n%s', out2)];
cmd = {cmd1, cmd2};

if status2 ~= 0
    warning('runServerTransfer:SafeMovePass1Failed', ...
        'SafeMove Pass 1 (copy) failed with exit status %d; aborting before Pass 2 (verified delete).', status2);
    status = status2;
    return
end

% ---- Pass 2 live: verified delete (source deleted only on a hash-verified match) ----
step2Extra = joinTokens([tokens, {'--maxSize', '0'}]);
[cmd3, status3, out3] = execTransfer(sourcePath, targetRoot, scriptPath, step2Extra, pythonExe, printCmd, ...
    'SafeMove Pass 2/2 (verified delete)');
cmdout = [cmdout, sprintf('\n===== SafeMove Pass 2/2 (verified delete) =====\n%s', out3)];
cmd = {cmd1, cmd2, cmd3};

if status3 ~= 0
    warning('runServerTransfer:SafeMovePass2Failed', 'SafeMove Pass 2 (verified delete) failed with exit status %d.', status3);
end
status = status3;

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
% Helper: hasFlag
% =======================================================================
function tf = hasFlag(tokens, flagName)
% True if a standalone flag (no value), e.g. '--dry-run', is present.
tf = any(strcmp(tokens, flagName));
end


% =======================================================================
% Helper: removeFlag
% =======================================================================
function tokens = removeFlag(tokens, flagName)
% Remove all occurrences of a standalone flag (no value), e.g. '--dry-run'.
tokens = tokens(~strcmp(tokens, flagName));
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
% Helper: parseTransferSummary
% =======================================================================
function [moved, errors] = parseTransferSummary(cmdout)
% Parse the "Done. Copied: X | Moved: Y | ... | Errors: E" summary line
% serverTransfer.py prints at the end of a run. Returns NaN for either
% value if it could not be found (treated as a failed check by the caller).
moved = NaN;
errors = NaN;
mTok = regexp(cmdout, 'Moved:\s*(\d+)', 'tokens');
if ~isempty(mTok)
    moved = str2double(mTok{end}{1});
end
eTok = regexp(cmdout, 'Errors:\s*(\d+)', 'tokens');
if ~isempty(eTok)
    errors = str2double(eTok{end}{1});
end
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
