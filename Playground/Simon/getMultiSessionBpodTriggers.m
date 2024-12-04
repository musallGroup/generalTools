function [trialNumbers, trialOnTimes, bhv] = getMultiSessionBpodTriggers(fPath, trialTriggerChan)
% function to get trial triggers from a digital line that was recorderded
% with the NI-DAQ with spikeGLX.

% TTL interpretation (to read barcodes)
shortInt = 2.5;
longInt = 5.5;
deadTime = 1000; %deadtime between trial triggers in ms

%% get behavioral data and compare trial counts between SessionData and trial triggers in SpikeGLX file

% find folders that contain mat files
recFolders = dir([fPath filesep '*' filesep '*.mat']);
recFolders = unique({recFolders.folder});

% loop over to find bpod sessions
clear bhv sessionStart
Cnt = 0;
for iRec = 1 : length(recFolders)
    cFile = findBhvFile(recFolders{iRec});

    if ~isempty(cFile)
        Cnt = Cnt + 1;
        load(fullfile(cFile(1).folder, cFile(1).name), 'SessionData');
        SessionData.recIdx(1:length(SessionData.date)) = Cnt;

        % keep paradigm name
        a = textscan(cFile(1).name, '%s%s%f%f%s', 'Delimiter', '_');
        SessionData.paradigmName = a{2};
        bhv{Cnt} = SessionData;
        sessionStart(Cnt) = SessionData.date(1);

    end
end

% make sure the order of session is based on time (with first recording
% being the first in the experiment).
[~, sortIdx] = sort(sessionStart);
bhv = bhv(sortIdx);

%% get digital triggers from niDAQ data
nidaqDir = dir(fullfile(fPath,'*_g0'));
nidaqDir = fullfile(fPath,nidaqDir.name);
metaName = dir(fullfile(nidaqDir,'*.nidq.meta'));
niMeta = gt_readSpikeGLXmeta(fullfile(metaName.folder, metaName.name));

trigDat = pC_extractDigitalChannel(nidaqDir, niMeta.nChans, niMeta.nChans, 'nidq'); %get digital channel from ni-daq. usually the lat channel
niSyncDat = trigDat{1}; %sync trrigers should be in the first digital line

% make sure first event is a trigger onset. otherwise delete first sample from trialEvents.
trialEvents = floor(trigDat{1}{trialTriggerChan}{1} *  1000); %get trigger onset times
if trigDat{1}{trialTriggerChan}{2}(1) > trigDat{1}{trialTriggerChan}{3}(1) 
    trialEvents(1) = [];
end

trialStartTrace = false(1, round(niMeta.fileTimeSecs * 1000));
for iEvents = 1 : 2 : length(trialEvents)
    if iEvents + 1 > length(trialEvents)
        trialStartTrace(trialEvents(iEvents) : end) = true;
    else
        trialStartTrace(trialEvents(iEvents) : trialEvents(iEvents+1)-1) = true;
    end
end

trialOnTimes = trigDat{1}{trialTriggerChan}{2}; %get trigger onset times
if length(trialOnTimes) > SessionData.nTrials * 1.5 %check for barcode triggers. This would lead to much more trial triggers compared to SessionData structure.
%     [trialNumbers, trialOnTimes] = segmentVoltageAndReadBarcodes(trialStartTrace, shortInt, longInt, 0.1, 0.5);
%     trialOnTimes = trialOnTimes(trialNumbers > -1) / 1000;
    
    trialNumbers = segmentVoltageAndReadBarcodes(trialStartTrace, shortInt, longInt, 0.1, 0.5);
    trialNumbers = trialNumbers(trialNumbers > -1);

    %find trial onset times by using the deadTime
    trialOnTimes = trialEvents([1; find(diff(trialEvents) > deadTime) + 1])' ./ 1000; 

    if length(trialNumbers) ~= length(trialOnTimes)
        error('The number of barcodes and trial onset times does not match. Check the trigger signal !!');
    end
    
else
    trialNumbers = 1 : length(trialOnTimes); %raw onset triggers. Assume that each trigger is a new trial.
end

% compare number of trial triggers
trialCnt = 0;
for iSessions = 1 : length(bhv)
    trialCnt = trialCnt + bhv{iSessions}.nTrials;
end

if length(trialNumbers) < trialCnt
    fprintf('!!! Bpod data has %d more trials as trial triggers in the SpikeGLX data. Make sure this is OK !!!\n', trialCnt - length(trialNumbers));
elseif any(trialNumbers > trialCnt)
    cIdx = trialNumbers > trialCnt;
    fprintf('!!! SpikeGLX has %d more trial triggers as trials in bpod data. Make sure this is OK !!!\n', sum(cIdx));
end