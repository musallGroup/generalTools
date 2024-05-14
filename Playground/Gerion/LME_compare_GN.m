function [pVal_cStim, tStat_cStim, fullmodel, modelCompare] = LME_compare_GN(dataIn, conditionID, randomVar)
% function to compare to variables, while controlling for the impact of the
% random variable "randomVar". The likelihood ratio test statistics LRStat 
% is indicative of whether dataIn2 has an impact on dataIn1, when
% controlling for the role of randomVar in a reduced model.
% SM 03.12.2023

% Adaptation by GN 2024-04-06: 
% From the description: "whether dataIn2 has an impact on dataIn1"
% At first, I thought this function gets all measurements in dataIn1 and 
% have dataIn2 be the stimulus labels (StimulusIDs). This was not the case,
% but I think it would be helpfull to organize the data like this. 
% This way, this function could be used with unmatched number of 
% observations. In addition, it would be great if we can use this function
% to test for the effect of genotype (Ctr vs. KO), where one animal can
% only ever be of one genotype. I wasn't sure if this just breaks the LME as
% any genotype effects could be explained as inter-individual effects, but
% I tested it and it seems to work just fine if the difference between 
% groups is large enough!
% 
% dataIn: vector of all measurements (concatenation of all conditions)
% conditionIDs: same length as dataIn. Labels listing which condition 
%               belongs to a given measures (e.g. Stimulus 1)
% randomVar: labels of random variable.
% 
% Row | dataIn (dF/F) | conditionID (stimulusID) | randomVar (animalID)
% 1     0.5             1                          2001
% 2     0.57            1                          2002
% 3     0.75            2                          2001
% 4     0.77            2                          2002


% Examples I used while testing:
% % dataIn = 1:100;
% dataIn = [1:50, (1:50)+20];
% conditionID = vec(repmat(1:2, 50, 1));
% randomVar = vec(repmat([1:2, 1:2], 25, 1));
% % randomVar = vec(repmat([1:2, 3:4], 25, 1));

% check that all inputs are vectors:
if (sum(size(dataIn) > 1) > 1) || (sum(size(conditionID) > 1) > 1) || (sum(size(randomVar) > 1) > 1)
    error("Check data shapes!");
end

% make sure inputs are column vectors:
conditionID = vec(double(conditionID));
dataIn = vec(double(dataIn));
randomVar = vec(double(randomVar));

% renamve for clarity and convenience
cStims = conditionID;
cData = dataIn;
cGroups = randomVar;

% create linear mixed-effect model with 1 fixed and 1 random variable.
% combine into one table and create model
tbl = table(cData, cStims, cGroups, 'VariableNames', {'cData', 'cStims', 'cGroups'});
fullmodel = fitlme(tbl, "cData ~ cStims + (1 |cGroups)");
pVal_cStim = fullmodel.Coefficients.pValue(2); %return p-Value for stimulus regressor in full model
tStat_cStim = fullmodel.Coefficients.tStat(2); %return p-Value for stimulus regressor in full model
disp(pVal_cStim)

if nargout > 3
    % Test the significance of the fixed effect "cStims"
    % This will provide a p-value indicating the significance of the impact of "cStims" on "cData"
    nullmodel = fitlme(tbl,"cData ~ 1 + (1|cGroups)");
    modelCompare = compare(nullmodel, fullmodel, "CheckNesting",true);
end
