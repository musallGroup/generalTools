function unzipNvcomp(archivePath, outputDir, pythonPath, forceCPU)
    % Restore a .nvcz archive (created by gpuCompressTIFwithNvcomp.m /
    % compressComplete2pSessions_DL.m) back to its original file.
    % GPU/nvCOMP counterpart to unzip7z.m.
    %
    % Works without any GPU at all for 'Zstd'/'LZ4' archives - nvcompTIF.py
    % auto-detects a missing/unusable nvcomp install and falls back to a
    % pure-CPU decoder (zstandard/lz4 pip packages, no CUDA needed) - so a
    % colleague restoring data years later on a GPU-less machine still can.
    % Every other algorithm (Bitcomp/GDeflate/ANS/Cascaded, and
    % Snappy/Deflate/Gzip which were never verified CPU-compatible) has no
    % CPU decoder and fails with a clear NO_CPU_FALLBACK message instead of
    % something broken.
    %
    % Requires: pip install nvidia-nvcomp-cu13 numpy (or nvidia-nvcomp-cu12,
    % matching your CUDA/driver) for the GPU path, or just zstandard + lz4
    % for the CPU-only path, in whatever Python environment pythonPath
    % resolves to.
    %
    % Inputs:
    % - archivePath: full path to the .nvcz file
    % - outputDir: folder to restore into (default: same folder as the archive)
    % - pythonPath: python executable/command (default 'python')
    % - forceCPU: force the CPU-only decode path even if a GPU/nvcomp is
    %   available (default false) - mainly for testing that path deliberately

    if ~exist('pythonPath', 'var') || isempty(pythonPath)
        pythonPath = 'python';
    end

    if ~exist('forceCPU', 'var') || isempty(forceCPU)
        forceCPU = false;
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
    if forceCPU
        cmd = [cmd ' --force-cpu'];
    end
    [status, result] = system(cmd, '-echo');

    if status ~= 0 || ~contains(result, 'DECOMPRESS_OK')
        error('Restore failed. Check paths and that nvcomp/python are set up correctly.\n%s', result);
    else
        fprintf('Restore complete: %s\n', outPath);
    end
end
