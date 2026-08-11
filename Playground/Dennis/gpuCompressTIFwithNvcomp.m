function [integrityCheck,zipOutputPath,verifiedOnDisk] = gpuCompressTIFwithNvcomp(tifFilePath, zipOutputPath, algorithm, pythonPath, verifyTier, verbose)
    % Compress a file using NVIDIA nvCOMP (GPU) and verify archive integrity.
    % GPU counterpart to compressTIFwith7zip.m, but runs on GPU via
    % nvcompTIF.py (NVIDIA nvCOMP Python API) instead of 7-Zip/LZMA on CPU.
    % Output is a custom .nvcz container, not a real .7z archive.
    %
    % A single nvcompTIF.py 'compress' call does encode + a mandatory
    % in-memory pre-write check + a post-write on-disk check, all in one
    % process (avoids duplicate Python/CUDA startup and enables the free
    % in-memory check). The post-write check's thoroughness is controlled by
    % verifyTier - see nvcompTIF.py's module docstring for the full safety
    % analysis of each tier. Default 'full' matches the original
    % compressTIFwith7zip.m contract exactly (reread the whole archive from
    % disk and fully decode it) and is the only tier actually used in
    % production; 'quick'/'memory' exist for possible future use on
    % non-critical data, not enabled by default anywhere in this toolset.
    %
    % Requires: pip install nvidia-nvcomp-cu13 numpy (or nvidia-nvcomp-cu12,
    % matching your CUDA/driver; add zstandard + lz4 too if you want the CPU
    % decompression fallback in unzipNvcomp.m) in whatever Python environment
    % pythonPath resolves to.
    %
    % Inputs:
    % - tifFilePath: full path to the input file (e.g. .tif)
    % - zipOutputPath: full path to output .nvcz file
    % - algorithm: nvCOMP codec, e.g. 'Zstd' (default), 'Bitcomp', 'GDeflate', 'LZ4'
    % - pythonPath: python executable/command (default 'python')
    % - verifyTier: 'full' (default), 'quick', or 'memory' - see above
    % - verbose: if true, echo live output to the command window (default false)
    %
    % Outputs:
    % - integrityCheck: true if it's safe (per the chosen tier) to delete the original
    % - zipOutputPath: path to the written archive
    % - verifiedOnDisk: true only if an actual post-write on-disk check ran and
    %   passed ('quick'/'full' success) - false for 'memory' tier, so callers can
    %   log an unmissable distinction between "verified" and "assumed good,
    %   unverified against on-disk bytes"

    if ~exist('zipOutputPath', 'var') || isempty(zipOutputPath)
        [~,~,fileEnd] = fileparts(tifFilePath);
        zipOutputPath = strrep(tifFilePath, fileEnd, '.nvcz');
    end

    if ~exist('algorithm', 'var') || isempty(algorithm)
        algorithm = 'Zstd';
    end

    if ~exist('pythonPath', 'var') || isempty(pythonPath)
        pythonPath = 'python';
    end

    if ~exist('verifyTier', 'var') || isempty(verifyTier)
        verifyTier = 'full';
    end

    if ~exist('verbose', 'var') || isempty(verbose)
        verbose = false;
    end

    funcPath = fileparts(which(mfilename));
    scriptPath = fullfile(funcPath, 'nvcompTIF.py');

    % Quote file paths in case they contain spaces
    tifFilePathQuoted = ['"' tifFilePath '"'];
    zipOutputPathQuoted = ['"' zipOutputPath '"'];

    cmd = sprintf('%s "%s" compress %s %s --algorithm %s --verify-tier %s', ...
        pythonPath, scriptPath, tifFilePathQuoted, zipOutputPathQuoted, algorithm, verifyTier);
    fprintf('Compressing file on GPU (%s, verify-tier=%s)...\n', algorithm, verifyTier);
    if verbose
        [status, result] = system(cmd, '-echo');
    else
        [status, result] = system(cmd);
    end

    [~,tifFile] = fileparts(zipOutputPath);
    if ~contains(result, 'COMPRESSION_OK')
        error('GPU compression failed:\n%s', result);
    end
    fprintf('Compression successful: %s.tif\n', tifFile);

    verifiedOnDisk = contains(result, 'INTEGRITY_OK');
    integrityCheck = status == 0 && (verifiedOnDisk || contains(result, 'INTEGRITY_SKIPPED'));

    if verifiedOnDisk
        fprintf('Archive integrity verified on disk (%s tier).\n', verifyTier);
    elseif integrityCheck
        fprintf('NOTE: integrity check SKIPPED (memory tier) - archive NOT verified against on-disk bytes.\n');
    else
        error('!!!! Archive integrity check failed !!!!\n%s', result);
    end
end
