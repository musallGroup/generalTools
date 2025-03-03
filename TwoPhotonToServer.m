function TwoPhotonToServer(basePath, targPath, targPath2, keepLocal)
% Function to move imaging data from local PC to the server or an external 
% HDD. Will copy all data but only delete large TIFs from the base folder.
%
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. F:\2p_PuffyPenguin\319\)
% serverPath should be the server or external HDD position where data 
% should be moved. In this location, a new folder will be created to match
% the local data format. E.g. targPath = 'D:\' will copy data to a new
% folder D:\2p_PuffyPenguin\319\ with the same formatting as the source.
%
% targPath2 works the same way as targPath, in case data should be moved to
% 2 separate external HDDs. If targPath2 is given but the path is not found
% the local data will not be deleted from the local PC.
%
% If keepLocal is true, local files will not be deleted after copying.

delSize = 1; %size in GB of TIF stacks that should be removed

if ~exist('keepLocal' , 'var') || isempty(keepLocal)
    keepLocal = false;
end

% check if second target is given and exists
copyRuns = 2; %whether to copy data to 1 or 2 target locations
if ~exist('targPath2' , 'var') || isempty(targPath2)
    targPath2 = [];
    copyRuns = 1;
else
    % check if root of second target exists
    root2 = targPath2;
    while true
        parentFolder = fileparts(root2);
        if isempty(parentFolder) || strcmp(parentFolder, root2)
            break;
        end
        root2 = parentFolder; % Move up one level
    end

    % Check if the root drive exists. Otherwhise keep local file.
    if ~isfolder(root2)
        disp('Root for second target does not exist. Will only copy to first target and keep local files.');
        copyRuns = 1;
        keepLocal = true; % keep local files
    end
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
newTargPath1 = strrep(basePath, rootStr, targPath);
newTargPath2 = strrep(basePath, rootStr, targPath2);

%% find sessions
cSessions = dir(fullfile(basePath));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
cSessions = cSessions([cSessions.isdir]);
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
disp('===================')
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, cSessions(iSessions).name);
    fprintf('Current folder (%d/%d): %s\n', iSessions, length(cSessions), cFolder);

    if ~isempty(dir([cFolder filesep '*.tif'])) % only copy if there are tif stacks in current folder
        for x = 1 : copyRuns
            if x == 1
                targFolder = fullfile(newTargPath1, cSessions(iSessions).name);
            elseif x == 2
                targFolder = fullfile(newTargPath2, cSessions(iSessions).name);
            end

            % make a full copy if target folder doesnt exist.
            % otherwise check if folder has been archieved already for individual files
            if exist(targFolder, 'dir') == 0
                copyfile(cFolder, targFolder);
            else
                disp('Folder already exists - checking for non-archived files.')

                %folder exists already check for non-archieved files
                sourceFiles = dir(cFolder);
                sourceFiles = {sourceFiles.name};
                sourceFiles = sourceFiles(3:end);
                targFiles = dir(targFolder);
                targFiles = strrep({targFiles.name}, '.p5c', ''); %archieved files

                for iFiles = 1 : length(sourceFiles)
                    if ~any(strcmpi(targFiles, sourceFiles(iFiles)))
                        cFile = fullfile(cFolder, sourceFiles{iFiles});
                        targFile = fullfile(targFolder, sourceFiles{iFiles});
                        copyfile(cFile, targFile);
                        fprintf('Copied file %s: %.0f/%.0f\n', cFile, iFiles, length(sourceFiles))
                    end
                end
            end
            fprintf('Copy %i complete\n', x);
        end

        %% check for large TIF stacks and delete
        cFiles = dir([cFolder filesep '*tif']);
        if ~keepLocal
            disp('Removing large TIF stacks from base folder.');
            for iFiles = 1 : length(cFiles)
                if cFiles(iFiles).bytes > (1024^3 * delSize) %file is larger than minimal size in GB - remove
                    delete(fullfile(cFiles(iFiles).folder,cFiles(iFiles).name));
                    fprintf('Deleted file %s\n', cFiles(iFiles).name)
                end
            end
            disp('Done.')
        else
            disp('Keeping local raw TIF stacks.')
        end
    else
        disp('No TIF files in current folder. Will not copy any data.')
    end
    disp('===================')
end