%% set some basic variables and get behavior
opts.cPath = '\\naskampa.kampa-10g\data\BpodBehavior\'; %for data from bpod setup
opts.savePath = 'D:\\BpodReports\';

% animal info
opts.cAnimal = '2939'; %animal name
opts.surgeryDate = '01-Oct-2023'; %date of surgery
opts.dateRange = {'01-Aug-2021', '12-Dec-2026'}; %date range

% pick paradigm
% opts.expType = 'Passiv visual stimulation'; %Experimental row A
% opts.expType = 'Visual discrimination'; %Experimental row B
opts.expType = 'Visual navigation'; %Experimental row C
% opts.expType = 'Multisensory discrimination'; %Experimental row D
% opts.expType = 'Multisensory navigation'; %Experimental row E

%% analysis for different paradigms in chronological order
opts.minTrials = 10;
cParadigms = dir([opts.cPath opts.cAnimal filesep]); %folder with behavioral data
cParadigms = cParadigms(~contains({cParadigms.name}, '.'));

allOut = [];
for iParams = 1 : length(cParadigms)
    opts.paradigm = cParadigms(iParams).name;
    passiveParadigms = {'OptoOwl', 'MotionMule', 'MotionMare', 'MultiMouse'}; %ignore passive paradigms
    if ~any(strcmpi(opts.paradigm, passiveParadigms))
        out = bpod_checkSessions(opts);
        allOut = bA_appendBehavior(allOut, out);
    end
end

% Loop through each field and sort it based on dates
fieldNames = fieldnames(allOut); % Get all field names in the struct
[a, cIdx] = sort(datenum(allOut.sessionTime));
cIdx = cIdx(diff([0;a])>0.3);
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    allOut.(fieldName) = allOut.(fieldName)(cIdx);
end

%% combine info into daily entries and save as markdown file name
% Define the output Markdown file name
if ~exist(opts.savePath); mkdir(opts.savePath); end
reportFile = fullfile(opts.savePath, [opts.cAnimal '_BPodReport.txt']);
fileID = fopen(reportFile, 'w');

fprintf(fileID, ['######## ' opts.cAnimal ' - Behavioral Task Report ########\n']);
fprintf(fileID, '==============================================================\n');
for iSessions = 1 : length(cIdx)
    
    fprintf(fileID, [allOut.sessionType{iSessions} '\n']);

    fprintf(fileID, '%s; Session duration: %.2f minutes\n', allOut.sessionTime{iSessions}, allOut.sessionDur(iSessions));
    fprintf(fileID, 'Performed trials: %i; Performance: %.2f percent\n', allOut.sessionTrialCount(iSessions), allOut.performance(iSessions)*100);
    fprintf(fileID, 'Total reward given: %.2f ml\n', allOut.sessionRewardAmount(iSessions));
    if ~isempty(allOut.sessionNotes{iSessions})
        fprintf(fileID, 'Notes: %s\n', allOut.sessionNotes{iSessions});
    end
    fprintf(fileID, '==============================================================\n');

%     cLine{end+1,1} = '==============================================================';    
%     cLine{end+1,1} = allOut.sessionType{iSessions};
%     cLine{end+1,1} = sprintf('%s; Session duration: %.2f minutes', allOut.sessionTime{iSessions}, allOut.sessionDur(iSessions));
%     cLine{end+1,1} = sprintf('Performed trials: %i; Performance: %.2f percent', allOut.sessionTrialCount(iSessions), allOut.performance(iSessions)*100);
%     cLine{end+1,1} = sprintf('Total reward given: %.2f ml', allOut.sessionRewardAmount(iSessions));
%     if ~isempty(allOut.sessionNotes{iSessions})
%         cLine{end+1,1} = sprintf('Notes: %s', allOut.sessionNotes{iSessions});
%     end
%     cLine{end+1,1} = '==============================================================';
    
end
fclose(fileID);