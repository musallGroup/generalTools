function modelCompare = LME_compare(dataIn1, dataIn2, randomVar)
% function to compare to variables, while controlling for the impact of the
% random variable 'randomVar'. The likelihood ratio test statistics LRStat 
% is indicative of whether dataIn2 has an impact on dataIn1, when
% controlling for the role of randomVar in a reduced model.
% SM 03.12.2023

% create linear midex-effect model with 1 fixed and 1 random variable.
cStims = repmat(1:2, size(dataIn1,1), 1); %index for the two test variables
cStims = cStims(:);
cData = cat(1, dataIn1(:), dataIn2(:)); %combine both inputs into 1 vector
cGroups = repmat(randomVar(:), 2, 1); %random grouping variable
cGroups = cGroups(:);

% combine into one table and create model
tbl = table(cData, cStims, cGroups, 'VariableNames',{'cData','cStims','cGroups'});
fullmodel = fitlme(tbl,'cData ~ cStims + (1|cGroups)');
nullmodel = fitlme(tbl,'cData ~ 1 + (1|cGroups)');

% Test the significance of the fixed effect 'cStims'
% This will provide a p-value indicating the significance of the impact of 'cStims' on 'cData'
modelCompare = compare(nullmodel, fullmodel, 'CheckNesting',true);
