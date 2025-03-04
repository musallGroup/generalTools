function bhvVideoToHDD(basePath, targPath, checkTape, keepLocal)
% Function to move behavioral data from bpod paradimgs from local PC to the
% exernal HDD. Will copy all data but only delete movies from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. E:\Bpod Local\Data\2482\PuffyPenguin\)
%
% targetPath should be the drive letter of the external HDD where data 
% should be moved.
%
% example usage:
% basePath = 'F:\Bpod Local\Data\320\PuffyPenguin';
% targPath  = 'G:\';
% checkTape = false;
% keepLocal = true;
% bhvVideoToHDD(basePath, targPath, checkTape, keepLocal)

if ~exist('keepLocal' , 'var') || isempty(keepLocal)
    keepLocal = true;
end

if ~exist('checkTape' , 'var') || isempty(checkTape)
    checkTape = true;
end

% extract the root folder and create new target paths
rootStr = basePath;
while true
    parentFolder = fileparts(rootStr);
    if isempty(parentFolder) || strcmp(parentFolder, rootStr)
        break;
    end
    rootStr = parentFolder; % Move up one level
end
newTargPath = strrep(basePath, rootStr, targPath);
newTargPath = strrep(newTargPath, 'Bpod Local\Data', 'BpodBehavior');

% find sessions
cSessions = dir(fullfile(basePath, 'Session Data'));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
cSessions = cSessions([cSessions.isdir]);
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, 'Session Data', cSessions(iSessions).name);
    targFolder = fullfile(newTargPath, 'Session Data', cSessions(iSessions).name);
    
    disp(['Current folder is ', cFolder]);
    if ~isfolder(targFolder)
        % check if recording has been moved to a subfolder
        folderCheck = dir([fullfile(newTargPath, 'Session Data\'), '*\' cSessions(iSessions).name]);
        if ~isempty(folderCheck)
            targFolder = folderCheck(1).folder;
        end
    end
    
    if ~isfolder(targFolder)
        disp('Current folder is missing on HDD. Uploading local data.');
        copyfile(cFolder, targFolder);
        disp('Copy complete.');
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
            if (any(strcmpi(tapeFiles, cFiles(iFiles).name)) && checkTape) || (exist(targFile, 'file') && v1.Duration == v2.Duration)
                clear v1 v2
                delete(sourceFile); %only delete local file if there is a copy on the server
                fprintf('Removed local file %s\n', sourceFile);
            else
                clear v1 v2
                error('something very weird happened - something wrong with server communication or server full??');
            end
        else
            clear v1 v2
            fprintf('Keeping file %s on local PC\n', sourceFile);
        end
    end
    disp('====================')
end