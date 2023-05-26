function [recInfo, recLabels] = getRecordingsFromGooglesheet(opts)
% function to select specific recordings for an animal of interest from a google sheet.
% the sheet needs to be visible for everyone with the link as a viewer.

%% --- Load the google sheets document "2photon acquisition record" --- %
% docid = '16MKB18byS2S7ATSopf2NJpVPFZnH-BJdh4NtvBY80_k'; %google sheet
expTable = GetGoogleSpreadsheet(opts.docid); % this function (GetGoogleSpreadsheet.m) needs to be downloaded

optsFields = fieldnames(opts)';
rowSelectIdx = true(size(expTable,1), 1);
for iChecks = 1 : length(expTable(1,:))
    checkIdx = ismember(optsFields, expTable{1, iChecks});
    
    if sum(checkIdx) > 0
        cIdx = contains(expTable(1,:), optsFields{checkIdx});
        rowSelectIdx = rowSelectIdx & ismember(expTable(:,cIdx), opts.(optsFields{checkIdx}));
    end
end
  
recInfo = expTable(rowSelectIdx,:);
recLabels = expTable(1,:);
