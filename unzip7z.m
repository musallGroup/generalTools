function unzip7z(archivePath, outputDir, sevenZipPath)
    % Full path to 7z.exe
    if ~exist('sevenZipPath', 'var') || isempty(sevenZipPath)
        sevenZipPath = '"C:\Program Files\7-Zip\7z.exe"'; % default path
    end
    
    % if output dir is not given extract into source folder
    if ~exist('outputDir', 'var') || isempty(outputDir)
        outputDir = fileparts(archivePath);
    end
    
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir') || isempty(outputDir)
        mkdir(outputDir);
    end
    
    % Build system command
    cmd = sprintf('%s x "%s" -o"%s" -y', sevenZipPath, archivePath, outputDir);
    
    % Run the command
    status = system(cmd, '-echo');
    
    if status ~= 0
        error('Extraction failed. Check paths and that 7z.exe is accessible.');
    else
        fprintf('Extraction complete to %s\n', outputDir);
    end
end
