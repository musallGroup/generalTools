function bhvVideoToTape(basePath, targPath)
% Function to move behavioral data from bpod paradimgs into a tapedrive folder.
% Will copy all data but only delete movies from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. \\naskampa\DATA\BpodBehavior\F129\PuffyPenguin\)
% if targPath is given it should match the formating of basePath to
% identify where data should be copied to. Otherwise, the function assumes
% that there is a folder ARCHIVE on the same server and will move data
% there (e.g. \\naskampa\DATA\ARCHIVE\BpodBehavior\F129\PuffyPenguin\).

% basePath = '\\naskampa\DATA\BpodBehavior\F129\PuffyPenguin';
% targPath = '\\naskampa\DATA\ARCHIVE\F129\PuffyPenguin';

if ~exist('targPath', 'var') || isempty(targPath)
    %assume that targPath is a folder 'ARCHIVE' on the same folder as the basePath
    baseIdx = strfind(basePath, filesep);
    
    % check if path is given with fileseperators (e.g. \\naskampa\data\).
    % In this case, use the second folder to get to the right server partition.
    if any(baseIdx == 1)
        baseIdx = baseIdx(baseIdx > 2);
        baseIdx = baseIdx(2);
    else
        baseIdx = baseIdx(1);
    end
    
    targServer = [basePath(1:baseIdx) 'ARCHIVE' filesep];
    targPath = strrep(basePath, basePath(1:baseIdx), targServer);

    % check if folder exist. Throw a test dialog if needed.
    if ~isfolder(targServer)
        out = questdlg(['The folder ' targServer ' does not exist. Create or cancel?'], 'No tapedrive folder', 'CREATE', 'CANCEL', 'CREATE');
        if ~strcmp(out, 'CREATE')
            error('No tapedriver folder found');
        end
    end
end
    
% find sessions
cSessions = dir(fullfile(basePath, 'Session Data'));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
cSessions = cSessions([cSessions.isdir]);
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, 'Session Data', cSessions(iSessions).name);
    targFolder = fullfile(targPath, 'Session Data', cSessions(iSessions).name);
    
    if ~isempty(dir([cFolder filesep '*' cSessions(iSessions).name '.mat']))
        fprintf('Current folder (%d/%d): %s\n', iSessions, length(cSessions), cFolder);
        copyfile(cFolder, targFolder);
        fprintf('Copy complete. Removing videos from base folder...');
        
        % check for video files and delete
        cFiles = dir([cFolder filesep '*.avi']);
        cFiles = [cFiles; dir([cFolder filesep '*.mp4'])];
        cFiles = [cFiles; dir([cFolder filesep '*.mkv'])];
        for iFiles = 1 : length(cFiles)
            delete(fullfile(cFolder, cFiles(iFiles).name))
        end
        fprintf(' Done.\n')
    end
end