function [trialCases, caseCnt, caseIdx] = checkStimData(StimData)
%function to resolve unique combinations of conditions that are contained
%in StimData. This is helpful to know which stimulus combinations were
%presented in a given session.

% find unique cases
for iTrials = 1 : size(StimData.VarVals,2)    
    if iTrials == 1
        trialCases = StimData.VarVals(:, iTrials);
    elseif ~any(sum(trialCases == StimData.VarVals(:, iTrials), 1) == size(StimData.VarVals,1))
        trialCases = [trialCases, StimData.VarVals(:, iTrials)];
    end
end

%count unique cases
caseIdx = zeros(size(StimData.VarVals,2), size(trialCases,2), 'logical');
caseCnt = zeros(size(trialCases,2), 1, 'single');
for iCases = 1 : size(trialCases,2)
    
    caseIdx(:,iCases) = sum(StimData.VarVals == trialCases(:,iCases), 1) == size(StimData.VarVals,1);
    caseCnt(iCases) = sum(caseIdx(:,iCases));
        
end
    
    