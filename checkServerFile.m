function [existsFlag, localFile] = checkServerFile(cFile, serverPath, localPath, fileOverwrite)
% checkServerFile  Check for a file locally or on a server and copy if needed
%
% [existsFlag, localFile] = checkServerFile(cFile, serverPath, localPath, fileOverwrite)
%
% Inputs:
%   cFile         - filename (with extension)
%   serverPath    - path to server directory
%   localPath     - path to local directory
%   fileOverwrite - logical flag (default = false)
%
% Outputs:
%   existsFlag    - true if file exists locally or was copied
%   localFile     - full path to local file (empty if not found)

if nargin < 4 || isempty(fileOverwrite)
    fileOverwrite = false;
end

localFile  = fullfile(localPath, cFile);
serverFile = fullfile(serverPath, cFile);
existsFlag = false;

localExists  = exist(localFile,  'file') == 2;
serverExists = exist(serverFile, 'file') == 2;

%% case 1: file exists in both locations → compare
if localExists && serverExists
    localInfo  = dir(localFile);
    serverInfo = dir(serverFile);

    sizeMatch = localInfo.bytes == serverInfo.bytes;
    dateMatch = abs(localInfo.datenum - serverInfo.datenum) < 1e-6;

    if sizeMatch && dateMatch
        fprintf('[checkServerFile] File verified (size + date match): %s\n', localFile);
        existsFlag = true;
        return
    end

    % mismatch → decide based on overwrite flag
    if fileOverwrite
        fprintf(['[checkServerFile] File mismatch detected.\n' ...
                 '  Overwriting local file with server version:\n  %s\n'], localFile);
        copyfile(serverFile, localFile);
    else
        warning(['checkServerFile:MismatchSkipped\n' ...
                 'File exists locally and on server but differs.\n' ...
                 'Keeping local file:\n  %s'], localFile);
    end

    existsFlag = true;
    return
end

%% case 2: file exists only locally
if localExists
    fprintf('[checkServerFile] File found locally: %s\n', localFile);
    existsFlag = true;
    return
end

%% case 3: file exists only on server → copy
if serverExists
    fprintf('[checkServerFile] File not local. Found on server:\n  %s\n', serverFile);

    if ~exist(localPath, 'dir')
        mkdir(localPath);
        fprintf('[checkServerFile] Created local directory: %s\n', localPath);
    end

    copyfile(serverFile, localFile);
    fprintf('[checkServerFile] Copied file to local path:\n  %s\n', localFile);

    existsFlag = true;
    return
end

%% case 4: file exists nowhere
fprintf('[checkServerFile] File NOT found locally or on server:\n  %s\n', cFile);
localFile  = '';
existsFlag = false;
end
