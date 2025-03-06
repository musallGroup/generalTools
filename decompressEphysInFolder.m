function decompressEphysInFolder(basePath)
% Function to decompress ephys data in .cbin format in a given NPX
% recording, given by basePath.

%% find ap.cbin files and decompress
cbinFiles = dir(fullfile(basePath, '**', '*ap.cbin'));
disp(['Current recording: ' basePath]);
for iFiles = 1 : length(cbinFiles)

    % current file
    cFile = fullfile(cbinFiles(iFiles).folder, cbinFiles(iFiles).name);
    
    % try to decompress ap.cbin file
    % this needs python and installed mtscomp (https://github.com/int-brain-lab/mtscomp) to work
    disp(['Decompressing file: '  cbinFiles(iFiles).name]);
    funcPath = fileparts(which(mfilename));
    commandStr = sprintf('python %s %s', fullfile(funcPath, 'decompressNPXfile.py'), cFile);
    [out, resp] = system(commandStr, '-echo'); %run compression
        
end
fprintf(' Done.\n')