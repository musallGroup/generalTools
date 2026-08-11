function compressComplete2pSessions_DL(targetPaths, varargin)
% Compress large TIF files in completed 2-photon session folders - GPU variant.
%
% Same session-discovery/failsafe logic as compressComplete2pSessions.m, but
% compresses on GPU via NVIDIA nvCOMP (gpuCompressTIFwithNvcomp.m /
% nvcompTIF.py) instead of CPU 7-Zip/LZMA. See that script's header for why:
% NVENC lossless video encoding tops out at 12-bit and can't losslessly hold
% these 16-bit ScanImage TIFFs, so nvCOMP (general lossless GPU byte
% compression, no bit-depth ceiling) is used instead.
%
% Requires: pip install nvidia-nvcomp-cu13 (or nvidia-nvcomp-cu12, matching
% your CUDA/driver) in whatever Python environment `python` resolves to.
%
% A session is considered complete when both a suite2p output folder and a
% *_trigDat.mat file are present (unless ignoreTrigDat is set). Only TIF
% files larger than minSize_GB are compressed. The original TIF is deleted
% only after a successful GPU-side integrity check (decoded size + SHA-256
% match). Output archives use a custom .nvcz container (not a real .7z file)
% - restore them with unzipNvcomp.m.
%
% All qualifying files are discovered first (so the total count/size is
% known upfront), then compressed with a byte-weighted progress bar + ETA
% and a per-file/total timer. The progress bar tracks position in the batch
% (file N of M), not bytes within a single file - nvCOMP's encode() is one
% blocking call with no progress callback, so within-file progress isn't
% available.
%
% Usage:
%   compressComplete2pSessions_DL('F:\2p_PuffyPenguin\479')
%   compressComplete2pSessions_DL({'F:\2p_PuffyPenguin\479', 'F:\2p_PuffyPenguin\480'})
%   compressComplete2pSessions_DL(paths, 'dryRun', true)
%   compressComplete2pSessions_DL(paths, 'minSize_GB', 2)
%   compressComplete2pSessions_DL(paths, 'ignoreTrigDat', true)
%   compressComplete2pSessions_DL(paths, 'algorithm', 'Bitcomp')
%   compressComplete2pSessions_DL(paths, 'pythonPath', '/home/user/nvcomp-env/bin/python')

p = inputParser;
addRequired(p,  'targetPaths');
addParameter(p, 'dryRun',        false);
addParameter(p, 'minSize_GB',    1);
addParameter(p, 'ignoreTrigDat', false);
addParameter(p, 'algorithm',     'Zstd'); % nvCOMP codec: 'Zstd', 'Bitcomp', 'GDeflate', 'LZ4', ...
addParameter(p, 'pythonPath',    'python'); % python executable with nvcomp installed - MATLAB's
    % system() calls don't reliably inherit shell PATH edits (e.g. venv activation), so pass an
    % absolute path here (e.g. '/home/user/nvcomp-env/bin/python') if 'python' isn't found.
parse(p, targetPaths, varargin{:});

dryRun        = p.Results.dryRun;
minSize_GB    = p.Results.minSize_GB;
ignoreTrigDat = p.Results.ignoreTrigDat;
algorithm     = p.Results.algorithm;
pythonPath    = p.Results.pythonPath;

if ischar(targetPaths)
    targetPaths = {targetPaths};
end

if dryRun
    disp('[DRY RUN] No files will be compressed or deleted.');
end

% ===== Phase 1: discover all qualifying large TIF files across all paths/sessions =====
queue = struct('cFile', {}, 'bytes', {});

for iPath = 1:numel(targetPaths)
    basePath = targetPaths{iPath};

    if ~isfolder(basePath)
        fprintf('Path not found, skipping: %s\n', basePath);
        continue;
    end

    cSessions = dir(basePath);
    cSessions = cSessions([cSessions.isdir]);
    cSessions = cSessions(~ismember({cSessions.name}, {'.', '..'}));

    fprintf('\nChecking %d session(s) in: %s\n', numel(cSessions), basePath);
    disp('===================');

    for j = 1:numel(cSessions)
        cFolder = fullfile(basePath, cSessions(j).name);
        fprintf('Session (%d/%d): %s\n', j, numel(cSessions), cSessions(j).name);

        % Skip if suite2p has not run (searched recursively - suite2p output isn't always
        % directly inside the session folder, e.g. it can be one level deeper per-recording)
        s2pMatches = dir(fullfile(cFolder, '**', 'suite2p'));
        if isempty(s2pMatches) || ~any([s2pMatches.isdir])
            disp('  Skipping: no suite2p output.');
            continue;
        end

        % Skip if trigger file is missing (also searched recursively, same reasoning)
        if ~ignoreTrigDat && isempty(dir(fullfile(cFolder, '**', '*_trigDat.mat')))
            disp('  Skipping: trigger file missing.');
            continue;
        end

        % Find large TIF files (dir() is case-insensitive on Windows, so '*.tif' alone already
        % matches '.TIF' too - scanning both patterns separately would double-count every file)
        tifFiles = dir(fullfile(cFolder, '**', '*.tif'));
        tifFiles = tifFiles([tifFiles.bytes] > 1024^3 * minSize_GB);

        if isempty(tifFiles)
            disp('  No large TIF files found.');
            continue;
        end

        for k = 1:numel(tifFiles)
            queue(end+1) = struct( ...                                            %#ok<AGROW>
                'cFile', fullfile(tifFiles(k).folder, tifFiles(k).name), ...
                'bytes', tifFiles(k).bytes);
            fprintf('  Queued: %s (%.1f GB)\n', tifFiles(k).name, tifFiles(k).bytes / 1024^3);
        end
    end

    disp('===================');
end

nTotal = numel(queue);
if nTotal == 0
    disp('No large TIF files found to compress.');
    return;
end
fprintf('\nFound %d file(s) to compress (%.1f GB total).\n', nTotal, sum([queue.bytes]) / 1024^3);

if dryRun
    fprintf('[DRY RUN] Would compress and delete the %d file(s) listed above.\n', nTotal);
    return;
end

% ===== Phase 2: compress, with a byte-weighted batch progress bar + timers =====
bytesTotal = sum([queue.bytes]);
bytesDone  = 0;
runTimer   = tic;

for idx = 1:nTotal
    cFile = queue(idx).cFile;
    [~, fileName, fileExt] = fileparts(cFile);

    printProgressBar(idx, nTotal, bytesDone, bytesTotal, toc(runTimer));
    fprintf('  Compressing on GPU: %s%s (%.1f GB)\n', fileName, fileExt, queue(idx).bytes / 1024^3);

    % Compress into a disposable temp path rather than the final .nvcz name, so a
    % stale/corrupted leftover archive from an interrupted prior attempt is never
    % touched until a verified-good replacement exists - this also means a corrupted
    % source TIF can never cost us an already-good archive: on failure below, the
    % old .nvcz (if any) is left completely untouched.
    zipPath = strrep(cFile, fileExt, '.nvcz');
    tempZipPath = [zipPath '.tmp'];
    if exist(tempZipPath, 'file')
        delete(tempZipPath); % always disposable - never a verified result
    end

    fileTimer = tic;
    [integrityCheck, ~] = gpuCompressTIFwithNvcomp(cFile, tempZipPath, algorithm, pythonPath);
    fprintf('  File time: %s\n', formatDuration(toc(fileTimer)));

    if integrityCheck
        if exist(zipPath, 'file')
            delete(zipPath);
        end
        movefile(tempZipPath, zipPath);

        disp('  Compression successful. Deleting original TIF.');
        delete(cFile);
        if exist(cFile, 'file')
            error('TIF file could not be deleted after compression: %s', cFile);
        end
    else
        fprintf('  WARNING: Compression failed for %s. Original TIF kept.\n', [fileName fileExt]);
        if exist(tempZipPath, 'file')
            delete(tempZipPath);
        end
    end

    bytesDone = bytesDone + queue(idx).bytes;
end

printProgressBar(nTotal + 1, nTotal, bytesDone, bytesTotal, toc(runTimer)); % final 100% line
fprintf('Done: %d/%d file(s) processed in %s.\n', nTotal, nTotal, formatDuration(toc(runTimer)));

end


function printProgressBar(idx, total, bytesDone, bytesTotal, elapsedSec)
% Batch progress bar, weighted by bytes (file sizes vary too much for a flat
% per-file average to give a meaningful ETA): [====>     ] 45% (5/11) | elapsed 2m14s | ETA 3m01s
barWidth = 30;
if bytesTotal > 0
    frac = bytesDone / bytesTotal;
else
    frac = 0;
end
nFilled = round(frac * barWidth);
barStr = ['[' repmat('=', 1, nFilled) repmat(' ', 1, barWidth - nFilled) ']'];

if bytesDone > 0
    throughput = bytesDone / elapsedSec; % bytes/sec
    etaSec = (bytesTotal - bytesDone) / throughput;
    etaStr = formatDuration(etaSec);
else
    etaStr = 'unknown';
end

fprintf('\n%s %d%% (%d/%d) | elapsed %s | ETA %s\n', ...
    barStr, round(frac * 100), min(idx, total), total, formatDuration(elapsedSec), etaStr);
end


function str = formatDuration(seconds)
% Format a duration in seconds as e.g. '1h 03m 12s', '5m 02s', or '42s'
seconds = max(0, round(seconds));
h = floor(seconds / 3600);
m = floor(mod(seconds, 3600) / 60);
s = mod(seconds, 60);
if h > 0
    str = sprintf('%dh %02dm %02ds', h, m, s);
elseif m > 0
    str = sprintf('%dm %02ds', m, s);
else
    str = sprintf('%ds', s);
end
end
