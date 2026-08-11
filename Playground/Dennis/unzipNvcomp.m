function unzipNvcomp(archivePath, outputDir, pythonPath)
    % Restore a .nvcz archive (created by gpuCompressTIFwithNvcomp.m /
    % compressComplete2pSessions_DL.m) back to its original file.
    % GPU/nvCOMP counterpart to unzip7z.m.
    %
    % Requires: pip install nvidia-nvcomp-cu13 (or nvidia-nvcomp-cu12,
    % matching your CUDA/driver) in whatever Python environment pythonPath
    % resolves to.
    %
    % Inputs:
    % - archivePath: full path to the .nvcz file
    % - outputDir: folder to restore into (default: same folder as the archive)
    % - pythonPath: python executable/command (default 'python')

    if ~exist('pythonPath', 'var') || isempty(pythonPath)
        pythonPath = 'python';
    end

    % if output dir is not given, restore into source folder
    if ~exist('outputDir', 'var') || isempty(outputDir)
        outputDir = fileparts(archivePath);
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    [~, archiveName] = fileparts(archivePath);
    outPath = fullfile(outputDir, [archiveName '.tif']);

    funcPath = fileparts(which(mfilename));
    scriptPath = fullfile(funcPath, 'nvcompTIF.py');

    cmd = sprintf('%s "%s" decompress "%s" "%s"', pythonPath, scriptPath, archivePath, outPath);
    [status, result] = system(cmd, '-echo');

    if status ~= 0 || ~contains(result, 'DECOMPRESS_OK')
        error('Restore failed. Check paths and that nvcomp/python are set up correctly.\n%s', result);
    else
        fprintf('Restore complete: %s\n', outPath);
    end
end
