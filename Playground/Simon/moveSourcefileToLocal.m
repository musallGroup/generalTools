%code to find raw data files in a stack of subfolders and move (!! not just
%copy !!) ALL OF THEM to a local target. 
% This function was created to move large raw data files, such as 
% temp_wh.dat from the server to a local HDD without deleting them. The 
% code leaves an info.txt file in the source location to inform to which PC 
% the data was moved.

moveFileName = 'temp_wh.dat'; %name of file to be moved to local target
sourcePath = '\\naskampa\lts\invivo_ephys\Neuropixels\';
targPath = 'D:\invivo_ephys\Neuropixels\';

[~,moveFile_noType] = fileparts(moveFileName); %get name without file type
targFiles = dir([sourcePath filesep '**' filesep moveFileName]);
pcName = getenv('COMPUTERNAME'); % get current PC name


%loop over found files and move them to differnet location
for iFiles = 1 : length(targFiles)

    cFile = targFiles(iFiles);

    cSourceFile = fullfile(cFile.folder, cFile.name); %path to source file
    cTargFile = strrep(cFile.folder, sourcePath, targPath); %path to save data to
    if ~exist(cTargFile, 'dir'); mkdir(cTargFile); end

    cTargFile = fullfile(cTargFile, moveFileName);

    % create text file to inform where the original file was moved
    infoFile = [moveFile_noType '_move_info.txt'];
    file = fopen(fullfile(cFile.folder, infoFile),'w');
    fprintf(file, 'Original file %s was moved to PC: %s\n', moveFileName, pcName);
    fprintf(file, 'Folder path on local PC: %s\n', cTargFile);
    fclose(file);
    
    % move the file
    movefile(cSourceFile, cTargFile, 'f');
end
