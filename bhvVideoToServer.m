function bhvVideoToServer(basePath, serverPath, checkTape, keepLocal)
% Function to move behavioral data from bpod paradimgs from local PC to the
% server. Will copy all data but only delete movies from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. E:\Bpod Local\Data\2482\PuffyPenguin\)
% serverPath should be the server partition where data should be moved
% ('data', 'lts', or 'lts2'). 
% If checkTape is true, files are only covered if they are not on the tape 
% drive already.
% If keepLocal is true, local files will not be deleted after copying.
%
% example usage:
% basePath = 'E:\Bpod Local\Data\2482\PuffyPenguin';
% serverPath  = 'lts';
% checkTape = false;
% bhvVideoToServer(basePath, serverPath, checkTape)

if ~exist('checkTape' , 'var') || isempty(checkTape)
    checkTape = false;
end

if ~exist('keepLocal' , 'var') || isempty(keepLocal)
    keepLocal = false;
end

if ~exist('serverPath', 'var') || isempty(serverPath)
    serverString = '\\naskampa.kampa-10g\lts\BpodBehavior\'; %assume this is the server folder. lts is default
else
%     serverString = ['\\naskampa.kampa-10g\' serverPath '\BpodBehavior\']; %assume this is the server folder, given the target partition.
    serverString = [serverPath '\BpodBehavior\']; %assume this is the server folder, given the target partition.
end
    
%check if 10GB network is present and switch to regular network otherwise
if ~exist(serverString, 'dir')
    serverString = strrep(serverString, 'naskampa.kampa-10g', 'naskampa');
end
    
%source and target path are under Bpod Local and BpodBehavoior by default
localString = 'Bpod Local\Data'; %assume this is the local folder
if ~contains(basePath, localString) %if not using Bpod Local, check BpodBehavior instead
    localString = 'BpodBehavior'; %assume this is the local folder        
end
baseIdx = strfind(basePath, localString);
baseIdx = baseIdx + length(localString);
targPath = strrep(basePath, basePath(1:baseIdx), serverString);

% confirm that base and target are not the same path
if strcmpi(basePath, targPath)
    error('Source and target folder are identical. This should not happen !!');
end

% find sessions
cSessions = dir(fullfile(basePath, 'Session Data'));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
cSessions = cSessions([cSessions.isdir]);
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, 'Session Data', cSessions(iSessions).name);
    targFolder = fullfile(targPath, 'Session Data', cSessions(iSessions).name);
    disp(['Current folder is ', cFolder]);
    
    if ~exist(targFolder, 'dir')
        % check if recording has been moved to a subfolder
        folderCheck = dir([fullfile(targPath, 'Session Data\'), '*\' cSessions(iSessions).name]);
        if ~isempty(folderCheck)
            targFolder = folderCheck(1).folder;
        end
    end
    
    if ~exist(targFolder, 'dir')
        disp('Current folder is missing on server. Uploading local data.');
        copyfile(cFolder, targFolder);
        disp('Copy complete. Removing videos from base folder...');
    end
    
    % check for video and widefield files and delete if there is a copy on the server
    cFiles = dir([cFolder filesep '*.avi']);
    cFiles = [cFiles; dir([cFolder filesep '*.mp4'])];
    cFiles = [cFiles; dir([cFolder filesep '*.mkv'])];
    cFiles = [cFiles; dir([cFolder filesep '*uint16.dat'])];
    
    %folder exists already check for non-archieved files
    tapeFolder = strrep(targFolder, 'BpodBehavior', 'RAWDATA\BpodBehavior');
    tapeFiles = dir(tapeFolder);
    tapeFiles = tapeFiles(3:end);
    tapeFiles = strrep({tapeFiles.name}, '.p5c', ''); %archieved files

    for iFiles = 1 : length(cFiles)
        
        sourceFile = fullfile(cFolder, cFiles(iFiles).name);
        targFile = fullfile(targFolder, cFiles(iFiles).name);
         
        % check if file needs to be copied or is on tape already
        if ~exist(targFile, 'file') && ~(any(strcmpi(tapeFiles, cFiles(iFiles).name)) && checkTape)
            copyfile(sourceFile, targFile); %make sure there is a copy on the server
            fprintf('Copied local file %s to server\n', sourceFile);
        end
        
        if ~(any(strcmpi(tapeFiles, cFiles(iFiles).name)) && checkTape) %only do this if file is not on tape already
            % check if video file is broken
            [~,~,fileType] = fileparts(cFiles(iFiles).name);
            if ~strcmpi(fileType, '.dat') && cFiles(iFiles).bytes > 0 %dont do this for widefield data or empty files
                v1 = VideoReader(sourceFile);
                v2 = VideoReader(targFile);
                if v1.Duration ~= v2.Duration
                    clear v2
                    copyfile(sourceFile, targFile); %make sure there is a copy on the server
                    fprintf('Copied local file %s to server\n', sourceFile);
                    v2 = VideoReader(targFile);
                end
            else
                clear v1 v2
                v1.Duration = 0;
                v2.Duration = 0;
            end
        end
        
        % check if local file can be deleted
        if ~keepLocal
            if (any(strcmpi(tapeFiles, cFiles(iFiles).name)) && checkTape) || (exist(targFile, 'file') && ~strcmpi(targFile, sourceFile) && v1.Duration == v2.Duration)
                clear v1 v2
                delete(sourceFile); %only delete local file if there is a copy on the server
                fprintf('Removed local file %s\n', sourceFile);
            else
                clear v1 v2
                error('something very weird happened - something wrong with server communication or server full??');
            end
        else
            clear v1 v2
            fprintf('Keeping local file %s on local PC\n', sourceFile);
        end
    end
end