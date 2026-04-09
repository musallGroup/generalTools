function TwoPhotonToServer(basePath, targPath, targPath2, keepLocal, useCompress, dryRun)
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
%
% Example usage:
% basePath = 'F:\2p_PuffyPenguin\320';
% targPath = 'D:\';
% targPath2 = 'H:\';
% keepLocal = false;
% TwoPhotonToServer(basePath, targPath, targPath2, keepLocal);

delSize = 1; %size in GB of TIF stacks that should be removed

if ~exist('keepLocal' , 'var') || isempty(keepLocal)
    keepLocal = true;
end

if ~exist('useCompress' , 'var') || isempty(useCompress)
    useCompress = false;
end

if ~exist('dryRun' , 'var') || isempty(dryRun)
    dryRun = false;
end

if dryRun
    disp('[DRY RUN] No files will be copied or deleted.');
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

    if ~isempty([dir([cFolder filesep '*.tif']); dir([cFolder filesep '*.7z'])]) % only copy if there are tif stacks in current folder
        
        if ~dryRun
            twoP_readSItriggerFromTIF_SM(cFolder); %get trigger signals from TIF stack before moving data
        else
            disp('[DRY RUN] Would call twoP_readSItriggerFromTIF_SM.');
        end

        %% find large TIF files and compress
        tifFiles = dir(fullfile(cFolder, '**', '*.tif'));
        tifFiles = [tifFiles; dir(fullfile(cFolder, '**', '*.TIF'))];
        tifFiles = [tifFiles; dir(fullfile(cFolder, '**', '*uint16.dat'))]; %also compress widefield data
        tifFiles = tifFiles([tifFiles.bytes] > (1024^3 * delSize)); % only compress large files
        
        % try to compress TIF file
        % this needs installed 7zip to work
        if useCompress
            for iFiles = 1 : length(tifFiles)
                
                cFile = fullfile(tifFiles(iFiles).folder, tifFiles(iFiles).name);
                if exist(fullfile(tifFiles(iFiles).folder, 'suite2p'), 'dir')
                    
                    disp(['Compressing file: '  tifFiles(iFiles).name]);
                    
                    tic; [integrityCheck, zipOutputPath] = compressTIFwith7zip(cFile); toc;
                    
                    % make sure that compression was successful
                    if integrityCheck
                        disp('Compression succesful. Deleting original TIF file.');
                        delete(cFile);
                        
                        %double-check that file was really deleted and produce error otherwise.
                        % It happened before that it was still on the server for some reason.
                        if exist(cFile, 'file')
                            error('TIF file could not be deleted. Is it still open somewhere else?');
                        end
                    else
                        disp('Compression failed. Check if 7z is installed in the base environment.');
                    end
                end
            end
        end

        % start moving data
        for x = 1 : copyRuns
            if x == 1
                targFolder = fullfile(newTargPath1, cSessions(iSessions).name);
            elseif x == 2
                targFolder = fullfile(newTargPath2, cSessions(iSessions).name);
            end

            % copy missing files to target folder, creating it if needed
            if ~dryRun
                if exist(targFolder, 'dir') == 0
                    mkdir(targFolder);   % ***********creates a folder if missing
                else
                    disp('Folder already exists - checking for non-archived files.')
                end

                sourceFiles = dir(cFolder);
                sourceFiles = {sourceFiles.name};
                sourceFiles = sourceFiles(3:end);
                targFiles = dir(targFolder);
                targFiles = strrep({targFiles.name}, '.p5c', ''); %archieved files

                for iFiles = 1 : length(sourceFiles)
                    if ~any(strcmpi(targFiles, sourceFiles(iFiles)))
                        cFile = fullfile(cFolder, sourceFiles{iFiles});
                        targFile = fullfile(targFolder, sourceFiles{iFiles});
                        fprintf('Copying file %s: %.0f/%.0f ...', cFile, iFiles, length(sourceFiles))
                        copyfile(cFile, targFile);
                        disp('done!');
                    end
                end
                fprintf('Copy %i complete\n', x);
            else
                fprintf('[DRY RUN] Would copy %s -> %s\n', cFolder, targFolder);
            end
        end

        %% check for large TIF stacks and delete
        delFiles = dir(fullfile(cFolder, '**', '*.tif'));
        delFiles = [delFiles; dir(fullfile(cFolder, '**', '*.7z'))];
        delFiles = [delFiles; dir(fullfile(cFolder, '**', '*uint16.dat'))];
        delFiles = delFiles([delFiles.bytes] > (1024^3 * delSize)); %only delete files of this minimal size
        if ~keepLocal && ~dryRun
            disp('Removing large TIF stacks from base folder.');
            for iFiles = 1 : length(delFiles)
                delete(fullfile(delFiles(iFiles).folder, delFiles(iFiles).name));
                fprintf('Deleted file %s\n', delFiles(iFiles).name)
            end
            disp('Done.')
        elseif ~keepLocal && dryRun
            for iFiles = 1 : length(delFiles)
                fprintf('[DRY RUN] Would delete %s\n', fullfile(delFiles(iFiles).folder, delFiles(iFiles).name))
            end
        else
            disp('Keeping local raw TIF stacks.')
        end
    else
        disp('No TIF files in current folder. Will not copy any data.')
    end
    disp('===================')
end