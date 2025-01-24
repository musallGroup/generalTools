function [trialNumbers, trialOnTimes, bhv] = getBpodTriggers_Neurophotometrics(fPath, trialTriggerChan, sessionStart, sessionEnd)
% function to get trial triggers from a digital line that was recorderded
% with the Photometry system from Neurophotometrics

% TTL interpretation (to read barcodes)
shortInt = 2.5;
longInt = 5.5;

if ~exist(trialTriggerChan, 'var') || isempty(trialTriggerChan)
    trialTriggerChan = 'input0'; %usually trial trigger is on line 0
end

%% get behavioral data and compare trial counts between SessionData and trial triggers in SpikeGLX file
bhvFiles = findBhvFile(fPath);
load(fullfile(bhvFiles(1).folder, bhvFiles(1).name));

%% check for correct csv file and load data
% make sure there is no fileseperator and the end of the path string
if fPath(end) == filesep
    fPath(end) = [];
end

[~, folderName] = fileparts(fPath);
csvFiles = dir([fPath filesep '*' folderName '*.csv']);
digitalFile = [];
for iFiles = 1 : length(csvFiles)
   
    cIdx = strfind(csvFiles(iFiles).name, folderName) + length(folderName) + 1;
    [~, checkName] = fileparts(csvFiles(iFiles).name(cIdx : end));
    try
        dt = datetime(checkName, 'InputFormat', 'yyyy-MM-dd''T''HH_mm_ss');
        digitalFile = fullfile(csvFiles(iFiles).folder, csvFiles(iFiles).name);
        break
    end
end
digitalData = readtable(digitalFile);

%% get digital triggers from photometry data

if any(strcmpi(digitalData.Properties.VariableNames, 'DigitalIOName'))
    var1 = 'DigitalIOName';
    var3 = 'DigitalIOState';
    var4 = 'SystemTimestamp';
else
    var1 = 'var1';
    var3 = 'var3';
    var4 = 'var4';
end

trigIdx = strcmpi(digitalData.(var1), trialTriggerChan); %events from trigger line

% get times of the trigger line from system clock
trialEvents = digitalData.(var4)(trigIdx);
if find(strcmpi(digitalData.(var3)(trigIdx), 'false'), 1) == 1
    trialEvents(1) = [];
end
trialEvents = round((trialEvents - sessionStart) * 1000); %these are system timestamps in miliseconds after session start

% create trigger trace to analyze barcodes
sessionDur = ceil((sessionEnd - sessionStart) * 1000); %duration of session in miliseconds
trialStartTrace = false(1, sessionDur);
for iEvents = 1 : 2 : length(trialEvents)
    if iEvents + 1 > length(trialEvents)
        trialStartTrace(trialEvents(iEvents) : end) = true;
    else
        trialStartTrace(trialEvents(iEvents) : trialEvents(iEvents+1)-1) = true;
    end
end

% extract barcodes from trigger sequence
[trialNumbers, trialOnTimes] = segmentVoltageAndReadBarcodes(trialStartTrace, shortInt, longInt, 0.1, 0.5);
trialOnTimes = trialOnTimes(trialNumbers > -1) / 1000;
trialNumbers = trialNumbers(trialNumbers > -1);

% compare number of trial triggers
bhv = SessionData;
if length(trialNumbers) < SessionData.nTrials
    fprintf('!!! Bpod data has %d more trials as trial triggers in the SpikeGLX data. Make sure this is OK !!!\n', SessionData.nTrials - length(trialNumbers));
    bhv = selectBehaviorTrials(SessionData, trialNumbers);
elseif any(trialNumbers > SessionData.nTrials)
    cIdx = trialNumbers > SessionData.nTrials;
    fprintf('!!! SpikeGLX has %d more trial triggers as trials in bpod data. Make sure this is OK !!!\n', sum(cIdx));
    trialNumbers(cIdx) = [];
    trialOnTimes(cIdx) = [];
end

% adjust trialOnTimes so that they point to the start of a bpod trial, not
% the start of the barcode sequence
barCodeStart = nan(1, bhv.nTrials);
for iTrials = 1 : length(barCodeStart)
    barCodeStart(iTrials) = bhv.RawEvents.Trial{iTrials}.States.trialCode1(1);
end
trialOnTimes = trialOnTimes - barCodeStart; %shift trial onset times to account for barcode start

