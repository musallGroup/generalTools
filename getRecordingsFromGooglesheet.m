function [recInfo, recLabels] = getRecordingsFromGooglesheet(opts)
% function to select specific recordings for an animal of interest from a google sheet.
% the sheet needs to be visible for everyone with the link as a viewer.

%% --- Load the google sheets document "2photon acquisition record" --- %
if isfield(opts, 'gid')
    expTable = GetGoogleSpreadsheet(opts.docid, opts.gid);
else
    expTable = GetGoogleSpreadsheet(opts.docid);
end
expTable = expTable(:, ~cellfun(@isempty,expTable(1,:))); %only use columns with valid header

optsFields = fieldnames(opts)';
rowSelectIdx = true(size(expTable,1), 1);
rowSelectIdx(1) = false;
for iChecks = 1 : length(expTable(1,:))
    checkIdx = ismember(optsFields, expTable{1, iChecks});
    
    if sum(checkIdx) > 0 && ~isempty(opts.(optsFields{checkIdx}))
        cIdx = contains(expTable(1,:), optsFields{checkIdx});
        cData = expTable(:,cIdx);
        cData = cellfun(@(x) strtrim(x), cData, 'UniformOutput', false); %make sure there are no spaces at the beginning or the ened of the string
        if iscell(opts.(optsFields{checkIdx}))
            nbOptions = size(opts.(optsFields{checkIdx}),2);
            rowMultSelectIdx = false(size(expTable,1),1);
            for iOption = 1:nbOptions
                rowMultSelectIdx = rowMultSelectIdx | strcmpi(cData,opts.(optsFields{checkIdx}){iOption});
            end
            rowSelectIdx = rowSelectIdx & rowMultSelectIdx;
        else
            rowSelectIdx = rowSelectIdx & strcmpi(cData, opts.(optsFields{checkIdx}));
        end
    end
end
