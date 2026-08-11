function [integrityCheck,zipOutputPath] = compressTIFwith7zip(tifFilePath, zipOutputPath, sevenZipPath, verbose)
    % Compress a TIF file using 7-Zip and verify archive integrity.
    % Inputs:
    % - tifFilePath: full path to the .tif file
    % - zipOutputPath: full path to output .7z file
    % - sevenZipPath: full path to 7z.exe (e.g., 'C:\Program Files\7-Zip\7z.exe')
    % - verbose: if true, echo 7-Zip's live progress to the command window (default false)

    if ~exist('zipOutputPath', 'var') || isempty(zipOutputPath)
        [~,~,fileEnd] = fileparts(tifFilePath);
        zipOutputPath = strrep(tifFilePath, fileEnd, '.7z');
    end

    if ~exist('sevenZipPath', 'var') || isempty(sevenZipPath)
        sevenZipPath = '"C:\Program Files\7-Zip\7z.exe"'; % default path
    end

    if ~exist('verbose', 'var') || isempty(verbose)
        verbose = false;
    end

    % Quote file paths in case they contain spaces
    tifFilePathQuoted = ['"' tifFilePath '"'];
    zipOutputPathQuoted = ['"' zipOutputPath '"'];

    % Step 1: Compress with max compression (-mx=9)
    compressCmd = sprintf('%s a -mx=9 %s %s', sevenZipPath, zipOutputPathQuoted, tifFilePathQuoted);
    fprintf('Compressing file...\n');
    if verbose
        [compressStatus, compressResult] = system(compressCmd, '-echo');
    else
        [compressStatus, compressResult] = system(compressCmd);
    end

    [~,tifFile] = fileparts(tifFilePath);
    if compressStatus == 0
        fprintf('Compression successful: %s.tif\n', tifFile);
    else
        error('Compression failed:\n%s', compressResult);
    end

    % Step 2: Test archive integrity
    testCmd = sprintf('%s t %s', sevenZipPath, zipOutputPathQuoted);
    if verbose
        [testStatus, testResult] = system(testCmd, '-echo');
    else
        [testStatus, testResult] = system(testCmd);
    end

    % make sure file passed integrity test
    integrityCheck = testStatus == 0 && contains(testResult, 'Everything is Ok');
    if integrityCheck
        fprintf('Archive integrity test passed.\n');
    else
        error('!!!! Archive integrity test failed !!!!');
    end
end
