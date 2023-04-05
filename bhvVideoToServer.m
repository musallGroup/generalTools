function bhvVideoToServer(basePath, targPath)
% Function to move behavioral data from bpod paradimgs from local PC to the
% server. Will copy all data but only delete movies from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. E:\Bpod Local\Data\2482\PuffyPenguin\)
% if targPath is given it should match the formating of basePath to
% identify where data should be copied to. Otherwise, the function assumes
% that there is a folder on the server and will move data
% there (e.g. \\naskampa\DATA\BpodBehavior\F129\PuffyPenguin\).

% basePath = 'E:\Bpod Local\Data\2482\PuffyPenguin';
% targPath = '\\naskampa\DATA\BpodBehavior\2482\PuffyPenguin\';

if ~exist('targPath', 'var') || isempty(targPath)
    localString = 'Bpod Local\Data'; %assume this is the local folder
    
    %assume that targPath is \\naskampa\data\BpodBehavoior\ as a default
    baseIdx = strfind(basePath, localString);
    baseIdx = baseIdx + length(localString);
    
    serverString = '\\naskampa\Data\BpodBehavior\'; %assume this is the server folder
    targPath = strrep(basePath, basePath(1:baseIdx), serverString);
end

% find sessions
cSessions = dir(fullfile(basePath, 'Session Data'));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, 'Session Data', cSessions(iSessions).name);
    targFolder = fullfile(targPath, 'Session Data', cSessions(iSessions).name);
    
    disp(['Current folder is ', cFolder]);
    
    if ~isfolder(targFolder)
        % check if recording has been moved to a subfolder
        folderCheck = dir([fullfile(targPath, 'Session Data\'), '*\' cSessions(iSessions).name]);
        if ~isempty(folderCheck)
            targFolder = folderCheck(1).folder;
        end
    end
    
    if ~isfolder(targFolder)
        disp('Current folder is missing on server. Uploading local data.');
        copyfile(cFolder, targFolder);
        disp('Copy complete. Removing videos from base folder...');
    end
    
    % check for video and widefield files and delete if there is a copy on the server
    cFiles = dir([cFolder filesep '*.avi']);
    cFiles = [cFiles; dir([cFolder filesep '*.mp4'])];
    cFiles = [cFiles; dir([cFolder filesep '*.mkv'])];
    cFiles = [cFiles; dir([cFolder filesep '*uint16.dat'])];
    for iFiles = 1 : length(cFiles)
        
        sourceFile = fullfile(cFolder, cFiles(iFiles).name);
        targFile = fullfile(targFolder, cFiles(iFiles).name);
        
        % check if file needs to be copied
        if ~exist(targFile, 'file')
            copyfile(sourceFile, targFile); %make sure there is a copy on the server
            fprintf('Copied local file %s to server\n', sourceFile);
        end
        
        % check if video file is broken
        [~,~,fileType] = fileparts(cFiles(iFiles).name);
        if ~strcmpi(fileType, '.dat') %dont do this for widefield data
            v1 = VideoReader(sourceFile);
            v2 = VideoReader(targFile);
            if v1.Duration ~= v2.Duration
                copyfile(sourceFile, targFile); %make sure there is a copy on the server
                fprintf('Copied local file %s to server\n', sourceFile);

                clear v2
                v2 = VideoReader(targFile);
            end
        else
            clear v1 v2
            v1.Duration = 0;
            v2.Duration = 0;
        end

        % check if local file can be deleted
        if exist(targFile, 'file') && v1.Duration == v2.Duration
            delete(sourceFile); %only delete local file if there is a copy on the server
            fprintf('Removed local file %s\n', sourceFile);
        else
            error('something very weird happened - something wrong with server communication or server full??');
        end
    end
end