function twoPhotonToTape(basePath, targPath, useCompress, keepLocal)
% Function to move imaging data to the tape drive.
% Will copy all data but only delete large TIFs from the base folder.
%
% Function to move two photon data from bpod paradimgs into a tapedrive folder.
% Will copy all data but only delete large TIFs from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. \\naskampa\DATA\BpodBehavior\F129\PuffyPenguin\)
% if targPath is given it should match the formating of basePath to
% identify where data should be copied to. Otherwise, the function assumes
% that there is a folder RAWDATA on the same server and will move data
% there (e.g. \\naskampa\DATA\RAWDATA\BpodBehavior\F129\PuffyPenguin\).
%
% basePath = '\\naskampa\DATA\BpodBehavior\F129\PuffyPenguin';
% targPath = '\\naskampa\DATA\RAWDATA\BpodBehavior\F129\PuffyPenguin';
%
% Compression needs installed 7zip programm to reduce size of large TIF
% stacks.

delSize = 1; %size in GB of TIF stacks that should be removed

if ~exist('useCompress' , 'var') || isempty(useCompress)
    useCompress = true;
end

if ~exist('keepLocal' , 'var') || isempty(keepLocal)
    keepLocal = false;
end

if ~exist('targPath', 'var') || isempty(targPath)
    %assume that targPath is a folder 'RAWDATA' on the same folder as the basePath
    baseIdx = strfind(basePath, filesep);
    
    % check if path is given with fileseperators (e.g. \\naskampa\data\).
    % In this case, use the second folder to get to the right server partition.
    if any(baseIdx == 1)
        baseIdx = baseIdx(baseIdx > 2);
        baseIdx = baseIdx(2);
    else
        baseIdx = baseIdx(1);
    end
    
    targServer = [basePath(1:baseIdx) 'RAWDATA' filesep];
    targPath = strrep(basePath, basePath(1:baseIdx), targServer);
    
    % check if folder exist. Throw a test dialog if needed.
    if ~isfolder(targServer)
        out = questdlg(['The folder ' targServer ' does not exist. Create or cancel?'], 'No tapedrive folder', 'CREATE', 'CANCEL', 'CREATE');
        if ~strcmp(out, 'CREATE')
            error('No tapedriver folder found');
        end
    end
end

%% find sessions
cSessions = dir(fullfile(basePath, 'Session Data'));
cSessions = cSessions(~(ismember({cSessions.name}, '..') | ismember({cSessions.name}, '.')));
cSessions = cSessions([cSessions.isdir]);
disp(['Found ' num2str(length(cSessions)) ' Sessions in total. Moving data...']);
disp('===================')
for iSessions = 1 : length(cSessions)
    
    cFolder = fullfile(basePath, 'Session Data', cSessions(iSessions).name);
    targFolder = fullfile(targPath, 'Session Data', cSessions(iSessions).name);
    
    if ~isempty(findBhvFile(cFolder))
        
        %% find large TIF files and compress
        fprintf('Current folder (%d/%d): %s\n', iSessions, length(cSessions), cFolder);
        tifFiles = dir(fullfile(cFolder, '**', '*.TIF'));
        tifFiles = tifFiles([tifFiles.bytes] > (1024^3 * delSize)); %potential tif stacks
        disp(['Current recording: ' basePath]);
        
        % try to compress TIF file
        % this needs installed 7zip to work
        if useCompress
            for iFiles = 1 : length(tifFiles)
                disp(['Compressing file: '  tifFiles(iFiles).name]);
                
                cFile = fullfile(tifFiles(iFiles).folder, tifFiles(iFiles).name);
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
        
        %% make a full copy if target folder doesnt exist.
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
            targFiles = strrep({targFiles.name}, '.p5c', ''); %dont copy already archieved files again
            
            for iFiles = 1 : length(sourceFiles)
                if ~any(strcmpi(targFiles, sourceFiles(iFiles)))
                    cFile = fullfile(cFolder, sourceFiles{iFiles});
                    targFile = fullfile(targFolder, sourceFiles{iFiles});
                    disp(cFile)
                    copyfile(cFile, targFile);
                    fprintf('Copied file %.0f/%.0f\n', iFiles, length(sourceFiles))
                end
            end
        end
        fprintf('Copy complete. ');
        
        %% check for large TIF or 7z files
        if ~keepLocal
            fprintf('Removing large files from base folder...');
            delFiles = dir(fullfile(cFolder, '**', '*.tif'));
            delFiles = [delFiles; dir(fullfile(cFolder, '**', '*.7z'))];
            delFiles = delFiles([delFiles.bytes] > (1024^3 * delSize)); %only delete files of this minimal size
            for iFiles = 1 : length(delFiles)
                if exist(fullfile(delFiles(iFiles).folder, 'suite2p'), 'dir') %make sure suite2p output exists
                    delete(fullfile(delFiles(iFiles).folder,delFiles(iFiles).name));
                else
                    fprintf('!!! Will NOT delete file %s because no suite2p output was present !!!\n', delFiles(iFiles).name)
                end
            end
            fprintf(' done.\n')
        else
            fprintf('Keeping local raw TIF stacks.\n')
        end
    end
    disp('===================')
end

