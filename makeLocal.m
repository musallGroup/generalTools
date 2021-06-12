function loadFile = makeLocal(fName, fPath, localPath)
% usage:  loadFile = makeLocal(fName, fPath, localPath)
% If localPath is valid, this function attempts to make a copy of the file
% fName in fPath if the copy doesnt exist already. It then returns the
% filename which can be used to load the file.


the file from there and create a copy if it doesnt exit.

if ~exist('localPath', 'var') || isempty(localPath)
    loadFile = fullfile(fPath, fName);
else
    
    try
        loadFile = fullfile(localPath, fName);
        % check if local file exists, copy otherwise
        if ~exist(loadFile, 'file')
            
            % check if path exists
            if ~exist(localPath, 'dir')
                mkdir(localPath);
            end
            
            copyfile(fullfile(fPath, fName), loadFile)
        end
        
    catch ME
        fprintf('Transfer to local path failed. Returning remote path instead.')
        disp(ME.message);
    end
end