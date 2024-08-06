function ephysToTape(basePath, useCompress, targPath)
% Function to move ephys data into a tapedrive folder.
% Will copy all data but only delete movies from the base folder.
% basePath should point to the folder of a specific mouse/paradigm
% combination (e.g. \\naskampa\DATA\BpodBehavior\F129\PuffyPenguin\)
% if targPath is given it should match the formating of basePath to
% identify where data should be copied to. Otherwise, the function assumes
% that there is a folder RAWDATA on the same server and will move data
% there (e.g. \\naskampa\DATA\RAWDATA\BpodBehavior\F129\PuffyPenguin\).
%
% basePath = '\\naskampa\DATA\BpodBehavior\F129\PuffyPenguin';
% targPath = '\\naskampa\DATA\RAWDATA\BpodBehavior\F129\PuffyPenguin';

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
    
    targPath = [basePath(1:baseIdx) 'RAWDATA' filesep];
    targFolder = strrep(basePath, basePath(1:baseIdx), targPath);
    
    % check if folder exist. Throw a test dialog if needed.
    if ~isfolder(targPath)
        out = questdlg(['The folder ' targPath ' does not exist. Create or cancel?'], 'No tapedrive folder', 'CREATE', 'CANCEL', 'CREATE');
        if ~strcmp(out, 'CREATE')
            error('No tapedriver folder found');
        end
    end
end

%% find ap.bin files
binFiles = dir(fullfile(basePath, '**', '*ap.bin'));
disp(['Current recording: ' basePath]);
for iFiles = 1 : length(binFiles)

    % current file
    cFile = fullfile(binFiles(iFiles).folder, binFiles(iFiles).name);
    
    % try to compress ap.bin file
    % this needs python and installed mtscomp (https://github.com/int-brain-lab/mtscomp) to work
    if useCompress
        disp(['Compressing file: '  binFiles(iFiles).name]);
        funcPath = fileparts(which(mfilename));
        commandStr = sprintf('python %s %s', fullfile(funcPath, 'compressNPXfile.py'), cFile);
        [out, resp] = system(commandStr, '-echo'); %run compression
        
        % make sure that compression was successful
        compFile = strrep(cFile, 'ap.bin', 'ap.cbin');
        chFile = strrep(cFile, 'ap.bin', 'ap.ch');
        if out == 0 && contains(resp, 'Checking: 100%') && exist(compFile, 'file') && exist(chFile, 'file')
            disp('Compression succesful. Deleting original ap.bin file.');
            delete(cFile);
            
            %double-check that file was really deleted and produce error otherwise. 
            % It happened before that ap.bin was still on the server for some reason.
            if exist(cFile, 'file')
                error('ap.bin file could not be deleted. Is it still open somewhere else?');
            end
        else
            disp('Compression failed. Check if mtscomp is installed in the base environment.');
        end
    end
end

%% copy files to tape folder
% otherwise check if folder has been archieved already for individual files
sourceFiles = dir(fullfile(basePath, '**', '*'));
useIdx = ~ismember({sourceFiles.name}, {'.', '..'}) & cellfun(@(x) isequal(x, 0), {sourceFiles.isdir}); %only look at files, not folders
sourceFiles = sourceFiles(useIdx);

targFiles = dir(fullfile(targFolder, '**', '*'));
useIdx = ~ismember({targFiles.name}, {'.', '..'}) & cellfun(@(x) isequal(x, 0), {targFiles.isdir}); %only look at files, not folders
targFiles = targFiles(useIdx);
targFiles = strrep({targFiles.name}, '.p5c', ''); %make sure already archieved files are not copied again

% loop through files and copy what isn't present in target folder already.
disp('Copying files to tape drive folder');
for iFiles = 1 : length(sourceFiles)
    if ~any(strcmpi(targFiles, sourceFiles(iFiles).name))
        cFile = fullfile(sourceFiles(iFiles).folder, sourceFiles(iFiles).name);
        targFile = strrep(cFile, basePath, targFolder); %replace basepath with targetpath for tape drive
%         disp(cFile)
        if ~exist(fileparts(targFile), 'dir')
            mkdir(fileparts(targFile));
            disp(['Created new folder: ' fileparts(targFile)]);
        end
        copyfile(cFile, targFile);
        if rem(iFiles, round(length(sourceFiles)/10)) == 0
            fprintf('Copied file %.0f/%.0f\n', iFiles, length(sourceFiles))
        end
    end
end

%% check for ap bin/cbin files in basefolders and delete
fprintf('Copy complete. Removing large binary files from base folder...');
delFiles = dir(fullfile(basePath, '**', '*.ap.bin'));
delFiles = [delFiles; dir(fullfile(basePath, '**', '*.ap.cbin'))];
for iFiles = 1 : length(delFiles)
    delete(fullfile(delFiles(iFiles).folder,delFiles(iFiles).name));
end
fprintf(' Done.\n')