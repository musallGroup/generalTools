function fileIncomplete = compareFileHeadAndTail(sourceFile, targFile, nBytes)
%COMPAREFILEHEADANDTAIL Compare first and last N bytes of two files.
%
% fileIncomplete = compareFileHeadAndTail(sourceFile, targFile)
% fileIncomplete = compareFileHeadAndTail(sourceFile, targFile, nBytes)
%
% The function returns TRUE if:
%   - file sizes differ
%   - first bytes differ
%   - last bytes differ
%   - target file tail is all zeros
%
% Intended as a fast heuristic to detect incomplete or failed file copies.

    if nargin < 3
        nBytes = 1000;
    end

    %% --- File existence and size check ---
    srcInfo  = dir(sourceFile);
    targInfo = dir(targFile);

    if isempty(srcInfo) || isempty(targInfo)
        fileIncomplete = true;
        disp('Source or target file does not exist.');
        return
    end

    % Size mismatch → immediately incomplete
    if srcInfo.bytes ~= targInfo.bytes
        warning('File sizes of source and target files differ (%d vs %d bytes).', ...
                srcInfo.bytes, targInfo.bytes);
        warning(['!!! DO NOT DELETE ORIGINAL FILE ' sourceFile '!!!']);
        fileIncomplete = true;
        return
    end

    fileSize = srcInfo.bytes;

    %% --- Determine how many bytes we can safely compare ---
    nCompare = min(nBytes, fileSize);

    %% --- Read first bytes ---
    fid = fopen(sourceFile, 'rb');
    sourceHead = fread(fid, nCompare, 'uint8');
    fclose(fid);

    fid = fopen(targFile, 'rb');
    targHead = fread(fid, nCompare, 'uint8');
    fclose(fid);

    %% --- Read last bytes ---
    fid = fopen(sourceFile, 'rb');
    fseek(fid, -nCompare, 'eof');
    sourceTail = fread(fid, nCompare, 'uint8');
    fclose(fid);

    fid = fopen(targFile, 'rb');
    fseek(fid, -nCompare, 'eof');
    targTail = fread(fid, nCompare, 'uint8');
    fclose(fid);

    %% --- Comparisons ---
    headMatches = isequal(sourceHead, targHead);
    tailMatches = isequal(sourceTail, targTail);
    targTailAllZero = all(targTail == 0);

    fileIncomplete = ~(headMatches && tailMatches && ~targTailAllZero);

    %% --- Warning ---
    if fileIncomplete
        warning(['!!! File copy may be incomplete or corrupted. ', ...
                 'Header/tail mismatch or zero-filled tail detected. !!!']);
        warning(['!!! DO NOT DELETE ORIGINAL FILE ' sourceFile '!!!']);
    end
end
