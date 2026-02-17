function restoreAviFromTapeTransfer(tapeSubfolder, varargin)
% restoreAviFromTapeTransfer
%
% Identify all *.avi files under a given TAPE_TRANSFER subfolder and
% restore them (copy back) into the corresponding SOURCE path if missing.
%
% Mapping logic:
%   \\server\share\TAPE_TRANSFER\RemainingPath\...\file.avi
%   -> \\server\share\RemainingPath\...\file.avi
%
% i.e. remove the single path component 'TAPE_TRANSFER' (case-insensitive).
%
% Usage:
%   restoreAviFromTapeTransfer('\\naskampa\lts\TAPE_TRANSFER\Proj\Session1');
%   restoreAviFromTapeTransfer('\\naskampa\lts\TAPE_TRANSFER\Proj\Session1','DryRun',true);
%
% Name-value options:
%   'DryRun'     (default false) : only print actions, do not copy
%   'Overwrite'  (default false) : if true, overwrite existing source files

p = inputParser;
p.addRequired('tapeSubfolder', @(x) ischar(x) || isstring(x));
p.addParameter('DryRun', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('Overwrite', false, @(x) islogical(x) || isnumeric(x));
p.parse(tapeSubfolder, varargin{:});
dryRun    = logical(p.Results.DryRun);
overwrite = logical(p.Results.Overwrite);

tapeSubfolder = char(tapeSubfolder);

if ~isfolder(tapeSubfolder)
    error('Folder does not exist: %s', tapeSubfolder);
end

% Recursively list all AVI files
aviFiles = dir(fullfile(tapeSubfolder, '**', '*.avi'));

restored = 0;
skipped  = 0;
errors   = 0;

fprintf('Scanning: %s\n', tapeSubfolder);
fprintf('Found %d .avi files\n', numel(aviFiles));
fprintf('Mode: %s | Overwrite: %d\n\n', ternary(dryRun,'DRY RUN','LIVE'), overwrite);

for i = 1:numel(aviFiles)
    srcInTape = fullfile(aviFiles(i).folder, aviFiles(i).name);

    % Compute corresponding source path by removing '\TAPE_TRANSFER\' once
    srcPath = removeTapeTransferComponent(srcInTape);

    if isempty(srcPath)
        fprintf('[SKIP] (no TAPE_TRANSFER component) %s\n', srcInTape);
        skipped = skipped + 1;
        continue;
    end

    if isfile(srcPath) && ~overwrite
        fprintf('[SKIP] exists: %s\n', srcPath);
        skipped = skipped + 1;
        continue;
    end

    fprintf('[RESTORE] %s\n        -> %s\n', srcInTape, srcPath);

    if ~dryRun
        try
            dstFolder = fileparts(srcPath);
            if ~isfolder(dstFolder)
                mkdir(dstFolder);
            end
            % copyfile returns [status,msg] form; use 'f' only if overwrite
            if overwrite
                copyfile(srcInTape, srcPath, 'f');
            else
                copyfile(srcInTape, srcPath);
            end
        catch ME
            fprintf(2, '[ERROR] copy failed: %s\n        %s\n', srcInTape, ME.message);
            errors = errors + 1;
            continue;
        end
    end

    restored = restored + 1;
end

fprintf('\n%s\n', repmat('-',1,80));
fprintf('Done. Restored: %d | Skipped: %d | Errors: %d\n', restored, skipped, errors);

end


function outPath = removeTapeTransferComponent(inPath)
% Remove the first occurrence of '\TAPE_TRANSFER\' (case-insensitive).
% Returns empty if not found.

% Normalize slashes to backslashes for predictable matching
p = strrep(inPath, '/', '\');

% Case-insensitive locate of '\TAPE_TRANSFER\'
pattern = '\TAPE_TRANSFER\';
pUpper  = upper(p);
patUpper = upper(pattern);

idx = strfind(pUpper, patUpper);
if isempty(idx)
    outPath = '';
    return;
end

k = idx(1);

% Remove exactly that component (keep everything before '\' + after)
before = p(1:k-1); % up to the slash before TAPE_TRANSFER
after  = p(k + length(pattern):end);

% Reconstruct: before + '\' + after
% (before already ends with '\' because pattern starts with '\')
outPath = [before '\' after];

% Clean any accidental double backslashes within the path part
% (preserve initial UNC prefix \\server\share)
if startsWith(outPath, '\\')
    prefix = '\\';
    rest = outPath(3:end);
    rest = regexprep(rest, '\\{2,}', '\');
    outPath = [prefix rest];
else
    outPath = regexprep(outPath, '\\{2,}', '\');
end

end


function y = ternary(cond, a, b)
if cond
    y = a;
else
    y = b;
end
end
