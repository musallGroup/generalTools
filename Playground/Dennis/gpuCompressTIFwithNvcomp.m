function [integrityCheck,zipOutputPath] = gpuCompressTIFwithNvcomp(tifFilePath, zipOutputPath, algorithm, pythonPath, verbose)
    % Compress a file using NVIDIA nvCOMP (GPU) and verify archive integrity.
    % GPU counterpart to compressTIFwith7zip.m - same two-step
    % compress-then-verify contract, but runs on GPU via nvcompTIF.py (NVIDIA
    % nvCOMP Python API) instead of 7-Zip/LZMA on CPU. Output is a custom
    % .nvcz container, not a real .7z archive.
    %
    % Requires: pip install nvidia-nvcomp-cu13 (or nvidia-nvcomp-cu12,
    % matching your CUDA/driver) in whatever Python environment pythonPath
    % resolves to.
    %
    % Inputs:
    % - tifFilePath: full path to the input file (e.g. .tif)
    % - zipOutputPath: full path to output .nvcz file
    % - algorithm: nvCOMP codec, e.g. 'Zstd' (default), 'Bitcomp', 'GDeflate', 'LZ4'
    % - pythonPath: python executable/command (default 'python')
    % - verbose: if true, echo live output to the command window (default false)

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

    if ~exist('verbose', 'var') || isempty(verbose)
        verbose = false;
    end

    funcPath = fileparts(which(mfilename));
    scriptPath = fullfile(funcPath, 'nvcompTIF.py');

    % Quote file paths in case they contain spaces
    tifFilePathQuoted = ['"' tifFilePath '"'];
    zipOutputPathQuoted = ['"' zipOutputPath '"'];

    % Step 1: Compress on GPU
    compressCmd = sprintf('%s "%s" compress %s %s --algorithm %s', ...
        pythonPath, scriptPath, tifFilePathQuoted, zipOutputPathQuoted, algorithm);
    fprintf('Compressing file on GPU (%s)...\n', algorithm);
    if verbose
        [compressStatus, compressResult] = system(compressCmd, '-echo');
    else
        [compressStatus, compressResult] = system(compressCmd);
    end

    [~,tifFile] = fileparts(zipOutputPath);
    if compressStatus == 0 && contains(compressResult, 'COMPRESSION_OK')
        fprintf('Compression successful: %s.tif\n', tifFile);
    else
        error('GPU compression failed:\n%s', compressResult);
    end

    % Step 2: Test archive integrity (only reads the archive itself, same as `7z t`)
    testCmd = sprintf('%s "%s" verify %s', pythonPath, scriptPath, zipOutputPathQuoted);
    if verbose
        [testStatus, testResult] = system(testCmd, '-echo');
    else
        [testStatus, testResult] = system(testCmd);
    end

    % make sure file passed integrity test
    integrityCheck = testStatus == 0 && contains(testResult, 'INTEGRITY_OK');
    if integrityCheck
        fprintf('Archive integrity test passed.\n');
    else
        error('!!!! Archive integrity test failed !!!!\n%s', testResult);
    end
end
