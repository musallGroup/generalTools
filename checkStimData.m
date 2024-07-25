function [trialCases, caseCnt, caseIdx, diffVarNames] = checkStimData(StimData, relevantVarNames)
%function to resolve unique combinations of conditions that are contained
%in StimData. This is helpful to know which stimulus combinations were
%presented in a given session.
%
% relevantVarNames can be given as an additional input to only check
% variables that match these variables of interest. usedVarNames are the
% names of the variables that match the rows in trialCases.

if ~exist('relevantVarNames', 'var') || isempty(relevantVarNames)
    relevantVarNames = StimData.VarNames;
end

% reduce VarVals based on relevantVarNames (only use relevant variables in
% the output)
varIdx = NaN(1, length(relevantVarNames));
for i = 1 : length(relevantVarNames)
    cIdx = find(ismember(StimData.VarNames,relevantVarNames(i)));
    if ~isempty(cIdx)
        varIdx(i) = cIdx;
    end
end

% only use variables of interest
varVals = NaN(length(relevantVarNames), size(StimData.VarVals,2));
varVals(~isnan(varIdx), :) = StimData.VarVals(varIdx(~isnan(varIdx)), :);
    
% find unique cases
diffVarNames = []; %names of variables which differ across cases
for iTrials = 1 : size(varVals,2)    
    if iTrials == 1
        trialCases = varVals(:, iTrials);
    elseif ~any(sum(trialCases == varVals(:, iTrials), 1) == size(varVals,1))
        trialCases = [trialCases, varVals(:, iTrials)];
        diffVarNames = [diffVarNames, StimData.VarNames(sum(trialCases == varVals(:, iTrials), 2) < size(trialCases,2))];
    end
end
diffVarNames = unique(diffVarNames);

%count unique cases
caseIdx = zeros(size(varVals,2), size(trialCases,2), 'logical');
caseCnt = zeros(size(trialCases,2), 1, 'single');
for iCases = 1 : size(trialCases,2)
    caseIdx(:,iCases) = sum(varVals == trialCases(:,iCases), 1) == size(varVals,1);
    caseCnt(iCases) = sum(caseIdx(:,iCases));
end

    