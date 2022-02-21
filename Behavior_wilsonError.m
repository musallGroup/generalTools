function [dataUpper, dataLower, pChoseHigh] = Behavior_wilsonError(choseHigh, nTrials)
z = 1.96;
pChoseHigh = choseHigh ./ nTrials;
dataUpper = (pChoseHigh + z^2./(2*nTrials) + z .* sqrt(pChoseHigh.*(1-pChoseHigh)./nTrials + z^2./(4*nTrials.^2))) ./ (1 + z^2./nTrials);
dataLower = (pChoseHigh + z^2./(2*nTrials) - z .* sqrt(pChoseHigh.*(1-pChoseHigh)./nTrials + z^2./(4*nTrials.^2))) ./ (1 + z^2./nTrials);
