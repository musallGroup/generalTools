function [pVals, tStats, fullmodel, modelCompare1, modelCompare2 ] = LME_compare_2vars(targData, predict1, predict2, randomVar)
% function to compare to role of two variables predict1 and predict2 to explain 
% 'targData' a mixed effect model, while controlling for the impact of the
% random variable 'randomVar'. The pVals and tStats are quantifying how predictive 
% predict1 or predict2 are of targData, when controlling for the role of randomVar in a reduced model.
% SM 09.01.2023


% combine into one table and create model
tbl = table(targData, predict1, predict2, randomVar, 'VariableNames',{'y','X1','X2', 'randomVar'});
fullmodel = fitlme(tbl,'y ~ X1 + X2 + (1 |randomVar)');
pVals = fullmodel.Coefficients.pValue(2:3); %return p-Value for both regressors in the full model
tStats = fullmodel.Coefficients.tStat(2:3); %return t-statistics for both regressors in the full model

if nargout > 3
    nullmodel1 = fitlme(tbl,'y ~ X1 + (1|randomVar)');
    nullmodel2 = fitlme(tbl,'y ~ X2 + (1|randomVar)');
    modelCompare1 = compare(nullmodel1, fullmodel, 'CheckNesting',true);
    modelCompare2 = compare(nullmodel2, fullmodel, 'CheckNesting',true);
end