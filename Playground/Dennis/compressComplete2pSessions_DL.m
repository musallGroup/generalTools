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
% Usage:
%   compressComplete2pSessions_DL('F:\2p_PuffyPenguin\479')
%   compressComplete2pSessions_DL({'F:\2p_PuffyPenguin\479', 'F:\2p_PuffyPenguin\480'})
%   compressComplete2pSessions_DL(paths, 'dryRun', true)
%   compressComplete2pSessions_DL(paths, 'minSize_GB', 2)
%   compressComplete2pSessions_DL(paths, 'ignoreTrigDat', true)
%   compressComplete2pSessions_DL(paths, 'algorithm', 'Bitcomp')

p = inputParser;
addRequired(p,  'targetPaths');
addParameter(p, 'dryRun',        false);
addParameter(p, 'minSize_GB',    1);
addParameter(p, 'ignoreTrigDat', false);
addParameter(p, 'algorithm',     'Zstd'); % nvCOMP codec: 'Zstd', 'Bitcomp', 'GDeflate', 'LZ4', ...
parse(p, targetPaths, varargin{:});

dryRun        = p.Results.dryRun;
minSize_GB    = p.Results.minSize_GB;
ignoreTrigDat = p.Results.ignoreTrigDat;
algorithm     = p.Results.algorithm;

if ischar(targetPaths)
    targetPaths = {targetPaths};
end

if dryRun
    disp('[DRY RUN] No files will be compressed or deleted.');
end

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
            cFile = fullfile(tifFiles(k).folder, tifFiles(k).name);
            fprintf('  Compressing on GPU: %s (%.1f GB)\n', tifFiles(k).name, tifFiles(k).bytes / 1024^3);

            if ~dryRun
                % Compress into a disposable temp path rather than the final .nvcz name, so a
                % stale/corrupted leftover archive from an interrupted prior attempt is never
                % touched until a verified-good replacement exists - this also means a corrupted
                % source TIF can never cost us an already-good archive: on failure below, the
                % old .nvcz (if any) is left completely untouched.
                [~,~,fileEnd] = fileparts(cFile);
                zipPath = strrep(cFile, fileEnd, '.nvcz');
                tempZipPath = [zipPath '.tmp'];
                if exist(tempZipPath, 'file')
                    delete(tempZipPath); % always disposable - never a verified result
                end

                tic;
                [integrityCheck, ~] = gpuCompressTIFwithNvcomp(cFile, tempZipPath, algorithm);
                toc;

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
                    fprintf('  WARNING: Compression failed for %s. Original TIF kept.\n', tifFiles(k).name);
                    if exist(tempZipPath, 'file')
                        delete(tempZipPath);
                    end
                end
            else
                fprintf('  [DRY RUN] Would compress and delete: %s\n', cFile);
            end
        end

        disp('===================');
    end
end
