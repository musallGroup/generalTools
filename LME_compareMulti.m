function [pVal_cStim, tStat_cStim, fullmodel, modelCompare, dataUsed] = ...
    LME_compareMulti(dataIn, conditionID, randomVar, modelType, transformType)
% Compare measurements across conditions using a mixed-effects model.
%
% INPUTS
%   dataIn         : Nx1 vector of observations
%   conditionID    : Nx1 vector of condition/group labels
%   randomVar      : Nx1 or NxK array / cell array of random-effect grouping variables
%   modelType      : 'normal' (default) or 'gamma'
%   transformType  : 'none' (default) or 'asinh'
%
% MODEL
%   cData ~ cStims + (1|randomVar1) + (1|randomVar2) + ...
%
% NOTES
% - 'normal' uses fitlme
% - 'gamma' uses fitglme with log link
% - Gamma requires strictly positive data
% - 'asinh' is useful for skewed data containing negative and positive values

if nargin < 4 || isempty(modelType)
    modelType = 'normal';
end
if nargin < 5 || isempty(transformType)
    transformType = 'none';
end

dataIn = dataIn(:);
conditionID = conditionID(:);

% allow vector input
if isvector(randomVar) && ~iscell(randomVar)
    randomVar = randomVar(:);
elseif iscell(randomVar) && isvector(randomVar)
    randomVar = randomVar(:);
end

% allow KxN instead of NxK
if size(randomVar,1) ~= numel(dataIn) && size(randomVar,2) == numel(dataIn)
    randomVar = randomVar';
end

if numel(dataIn) ~= numel(conditionID) || size(randomVar,1) ~= numel(dataIn)
    error('Inputs must have matching number of observations.');
end

% optional transformation
switch lower(transformType)
    case 'none'
        dataUsed = double(dataIn);
    case 'asinh'
        dataUsed = asinh(double(dataIn));
    otherwise
        error('Unknown transformType. Use ''none'' or ''asinh''.');
end

cStims = categorical(conditionID);
tbl = table(dataUsed, cStims, 'VariableNames', {'cData','cStims'});

modelString = 'cData ~ cStims';
for i = 1:size(randomVar,2)
    varName = ['randomVar' num2str(i)];
    tbl.(varName) = categorical(randomVar(:,i));
    modelString = [modelString ' + (1|' varName ')'];
end

switch lower(modelType)
    case 'normal'
        fullmodel = fitlme(tbl, modelString);

    case 'gamma'
        if any(dataUsed <= 0)
            error('Gamma GLMM requires strictly positive data after transformation.');
        end
        fullmodel = fitglme(tbl, modelString, ...
            'Distribution', 'Gamma', ...
            'Link', 'log');

    otherwise
        error('Unknown modelType. Use ''normal'' or ''gamma''.');
end

coefNames = fullmodel.CoefficientNames;
idx = find(contains(coefNames, 'cStims_'));

if isempty(idx)
    error('Could not identify coefficient(s) for cStims.');
elseif numel(idx) > 1
    error('conditionID has more than two levels. This function currently returns only a single p-value/t-stat.');
end

pVal_cStim = fullmodel.Coefficients.pValue(idx);
tStat_cStim = fullmodel.Coefficients.tStat(idx);

if nargout > 3
    nullmodelString = regexprep(modelString, '^cData ~ cStims', 'cData ~ 1');

    switch lower(modelType)
        case 'normal'
            nullmodel = fitlme(tbl, nullmodelString);
        case 'gamma'
            nullmodel = fitglme(tbl, nullmodelString, ...
                'Distribution', 'Gamma', ...
                'Link', 'log');
    end

    modelCompare = compare(nullmodel, fullmodel, 'CheckNesting', true);
end
end
