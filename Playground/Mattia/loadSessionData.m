function SessionData = loadSessionData(inputPath)
    % Get the parent directory of inputPath
    parentDir = fileparts(inputPath);
    % Build the full path to SessionData.mat
    matFile   = fullfile(parentDir, 'SessionData.mat');
    % Check that it exists
    if ~exist(matFile, 'file')
        error('SessionData.mat not found in %s', parentDir);
    end
    % Load the .mat file
    s = load(matFile);
    SessionData = s.SessionData;
end
