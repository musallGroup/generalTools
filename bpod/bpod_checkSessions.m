function out = bpod_checkSessions(opts)
% Check behavioral data from individual sessions and collect in larger
% array. Also returns performance for each session.
rng("default")

%% get files and date for each recording
if ~isempty(opts.paradigm)
    fPath = [opts.cPath opts.cAnimal filesep opts.paradigm '\Session Data\']; %folder with behavioral data
    for iChecks = 1:2 %check for files repeatedly. Sometimes the server needs a moment to be indexed correctly
        files = dir([fPath '*' filesep opts.cAnimal '_' opts.paradigm '*.mat']); %behavioral files in correct cPath

        %identify behavioral files
        fileSelect = false(1, length(files));
        for iFiles = 1 : length(files)
            try
                cFile = fullfile(files(iFiles).folder, files(iFiles).name);
                a = whos('-file', cFile);
                fileSelect(iFiles) = any(strcmpi({a(:).name}, 'SessionData'));
            end
        end
        files = files(fileSelect);
        if ~isempty(files)
            break;
        end
        pause(0.1);
    end
    folders = {files.folder}';

else
    fPath = [opts.cPath filesep opts.paradigm filesep opts.cAnimal filesep]; %folder with behavioral data
    for iChecks = 1:10 %check for files repeatedly. Sometimes the server needs a moment to be indexed correctly
        files = dir([fPath '*' filesep 'task_data']); %behavioral files in correct cPath
        if ~isempty(files)
            break;
        end
        pause(0.1);
    end
    files = unique({files(:).folder})'; %isolate unique folder paths
    folders = fileparts(files);
end

% check that folders is a cell not a char array. Can happen when only one
% folder exists.
if ischar(folders)
    folders = {folders};
end

%% check daterange and reduce range of recordings if requested
if isfield(opts, 'dateRange') && ischar(opts.dateRange{1}) && ischar(opts.dateRange{2})
    opts.dateRange = datenum(opts.dateRange,'dd-mm-yyyy')'; %convert to date numbers if needed
else
    opts.dateRange = [1, inf];
end

%% remove files outside of the date range
useRec = false(1,size(files,1));
recDate = NaN(1,size(files,1));
for iFiles = 1:size(files,1)

    [~,a] = fileparts(folders{iFiles});
    try
        if ~isempty(opts.paradigm)
            recDate(iFiles) = datenum(a,'yyyymmdd_HHMMSS');
        else
            recDate(iFiles) = datenum(a,'yyyy-mm-dd_HH-MM-SS');
        end

        % if recording is in date range
        if recDate(iFiles) >= opts.dateRange(1) && recDate(iFiles) <= opts.dateRange(2)
            useRec(iFiles) = true;
        end

    catch
        useRec(iFiles) = false; %dont use if date comparison fails
    end
end
files = files(useRec);
recDate = recDate(useRec);

fprintf('Current animal %s, %G/%G recordings in correct date range\n', opts.cAnimal, sum(useRec), length(useRec))
fprintf('First rec: %s - Last rec: %s\n', datestr(min(recDate)), datestr(max(recDate)));

%% load data
useData = false(1, length(files));
performance = nan(1, length(files));
sessionDur = zeros(1, length(files));
sessionTrialCount = zeros(1, length(files));
sessionRewardAmount = zeros(1, length(files));
sessionTime = cell(length(files), 1);
sessionType = cell(length(files), 1);
sessionNotes = cell(length(files), 1);
switchCnt = 0;
fprintf('%i files found\n', length(files));

for iFiles = 1:size(files,1)

    clear SessionData
    if isempty(opts.paradigm)
        [SessionData, bhvFile] = bA_convertTeensySessionData(files{iFiles}, opts);
    else
        bhvFile = fullfile(files(iFiles).folder, files(iFiles).name);
        load(bhvFile, 'SessionData'); %load current bhv file
    end

    %this gets some information for current session
    sessionTrialCount(iFiles) = SessionData.nTrials;
    normIdx = false(1, SessionData.nTrials);
    if isfield(SessionData, 'DidNotChoose')
        sessionTrialCount(iFiles) = sum(~SessionData.DidNotChoose);
        normIdx = ~SessionData.DidNotChoose; %only trials that were responded to
    end
    if isfield(SessionData, 'Assisted')
        if length(normIdx) == length(SessionData.Assisted) && sum(SessionData.Assisted) > 0
            normIdx = normIdx & SessionData.Assisted; %only non-assisted trials for performance
        else
            normIdx = normIdx & ~SessionData.SingleSpout; %only non-assisted trials for performance
        end
        if ~isempty(opts.paradigm) && contains(files(iFiles).name, 'LickingLama')
            normIdx = SessionData.Assisted;
        end
    end

    performance(1, iFiles) = nan;
    if isfield(SessionData, 'Rewarded')
        performance(1, iFiles) = sum(SessionData.Rewarded(normIdx)) / sum(normIdx);
    end
    useData(iFiles) = sessionTrialCount(iFiles) > opts.minTrials || iFiles < 3; %if file contains enough performed trials

    sessionTime{iFiles} = datestr(recDate(iFiles));
    if ~isfield(SessionData, 'sessionDur'); SessionData.sessionDur = SessionData.SessionDur; end
    sessionDur(iFiles) = SessionData.sessionDur;
    sessionRewardAmount(iFiles) = SessionData.givenReward;
    selfPerformFraction = sum(normIdx) / length(normIdx);

    if ~isfield(opts, 'expType')
        opts.expType = 'Visual navigation';
    end
    currentState = [];
    if strcmpi(opts.expType, 'Passiv visual stimulation')
        currentState = [];
    elseif selfPerformFraction < 0.5
        currentState = 'Basic task performance';
    elseif selfPerformFraction < 0.7
        currentState = 'Intermediate task performance';
    else
        currentState = 'Expert task performance';
        if performance(1, iFiles) < 0.7
            currentState = 'Intermediate task performance';
        end
    end
    sessionType{iFiles} = sprintf('%s - %s', opts.expType, currentState);
    %     sessionType{iFiles} = opts.expType;

    if useData(iFiles) && iFiles > 1
        if floor(recDate(iFiles)) == floor(recDate(iFiles-1))
            if sessionTrialCount(iFiles) > sessionTrialCount(iFiles -1)
                useData(iFiles-1) = false;
            else
                useData(iFiles) = false;
            end
        end
    end

    if useData(iFiles)
        saveFile = strrep(bhvFile, opts.cPath, opts.savePath);
        if ~exist(fileparts(saveFile), 'dir'); mkdir(fileparts(saveFile)); end
        if ~exist(strrep(bhvFile, opts.cPath, opts.savePath), 'file')
            save(strrep(bhvFile, opts.cPath, opts.savePath), 'SessionData'); %make local copy for reproduceability
        end
        sessionNotes{iFiles} = [];
        if switchCnt == 0 %first session
            sessionNotes{iFiles} = strjoin([sessionNotes{iFiles}, {'Start of basic training'}]);
            switchCnt = switchCnt + 1;

        elseif switchCnt == 1 && strcmpi(currentState, 'Intermediate task performance') && isempty(sessionNotes{iFiles-1})
            sessionNotes{iFiles} = strjoin([sessionNotes{iFiles}, {'Start of Intermediate training'}]);
            switchCnt = switchCnt + 1;

        elseif switchCnt == 2 && strcmpi(currentState, 'Expert task performance')
            sessionNotes{iFiles} = strjoin([sessionNotes{iFiles}, {'Start of Expert training'}]);
            switchCnt = switchCnt + 1;
        end
        sessionTrialCount(iFiles) = SessionData.nTrials;
    end

    if rem(iFiles, round(length(files) / 10)) == 0
        fprintf('%i/%i complete\n', iFiles, length(files));
    end
end
disp('done');

%%
clear out
out.performance = performance(useData);
out.sessionDur = sessionDur(useData);
out.sessionTime = sessionTime(useData);
out.sessionTrialCount = sessionTrialCount(useData);
out.sessionRewardAmount = sessionRewardAmount(useData);
out.sessionType = sessionType(useData);
out.sessionNotes = sessionNotes(useData);
