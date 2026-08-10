function compressComplete2pSessions(targetPaths, varargin)
% Compress large TIF files in completed 2-photon session folders.
%
% A session is considered complete when both a suite2p output folder and a
% *_trigDat.mat file are present (unless ignoreTrigDat is set). Only TIF
% files larger than minSize_GB are compressed. The original TIF is deleted
% after a successful integrity check.
%
% Usage:
%   compressComplete2pSessions('F:\2p_PuffyPenguin\479')
%   compressComplete2pSessions({'F:\2p_PuffyPenguin\479', 'F:\2p_PuffyPenguin\480'})
%   compressComplete2pSessions(paths, 'dryRun', true)
%   compressComplete2pSessions(paths, 'minSize_GB', 2)
%   compressComplete2pSessions(paths, 'ignoreTrigDat', true)

p = inputParser;
addRequired(p,  'targetPaths');
addParameter(p, 'dryRun',        false);
addParameter(p, 'minSize_GB',    1);
addParameter(p, 'ignoreTrigDat', false);
parse(p, targetPaths, varargin{:});

dryRun        = p.Results.dryRun;
minSize_GB    = p.Results.minSize_GB;
ignoreTrigDat = p.Results.ignoreTrigDat;

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

        % Skip if suite2p has not run
        if ~isfolder(fullfile(cFolder, 'suite2p'))
            disp('  Skipping: no suite2p output.');
            continue;
        end

        % Skip if trigger file is missing
        if ~ignoreTrigDat && isempty(dir(fullfile(cFolder, '*_trigDat.mat')))
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
            fprintf('  Compressing: %s (%.1f GB)\n', tifFiles(k).name, tifFiles(k).bytes / 1024^3);

            if ~dryRun
                tic;
                [integrityCheck, ~] = compressTIFwith7zip(cFile);
                toc;

                if integrityCheck
                    disp('  Compression successful. Deleting original TIF.');
                    delete(cFile);
                    if exist(cFile, 'file')
                        error('TIF file could not be deleted after compression: %s', cFile);
                    end
                else
                    fprintf('  WARNING: Compression failed for %s. Original TIF kept.\n', tifFiles(k).name);
                end
            else
                fprintf('  [DRY RUN] Would compress and delete: %s\n', cFile);
            end
        end

        disp('===================');
    end
end
