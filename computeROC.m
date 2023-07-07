function [AUC, dPrime, hit, fa] =  computeROC(respA, respB, binEdges, showPlot)
% usage: [AUC, dPrime, hit, fa] =  computeROC(respA, respB, binEdges, showPlot)
% function to compute the AUC (area under the curce) using receiver
% operator characeristics (ROC). respA and respB are response distribution
% for two different stimuli, binEdges denote the x-Axis for the
% distributions. if showPlot is true, the function makes some plots to
% illustrate how the ROC is generated.

if ~exist('showPlot', 'var') || isempty(showPlot)
    showPlot = true;
end

%% Example data
b = normrnd(10,1,1,1000);
a = normrnd(25,1,1,1000);
binEdges = 0:0.5:30;

respA = histcounts(a, binEdges);
respB = histcounts(b, binEdges);

%% get ROC
for i = 1:1:length(binEdges)
    fa(i)  = sum(respA(i:end));  % False Alarm
    hit(i) = sum(respB(i:end)); % Hits
end

% turn into probabilities between 0 and 1
fa = fa ./ sum(respA);
hit = hit ./ sum(respB);


% Berechnung der Differenzfläche ROC-Referenz
% Die Fläche unter der Referenz-Linie beträgt immer genau 0.5! 
AUC = (trapz(fa,hit)) * -1;

% d' Berechnen mit einer inversen probit-function (phi hoch-1)
% multipliziert mit der Wurzel aus 2. Die Wurzel zwei ist notwendig, da 
dPrime = normcdf(AUC) * sqrt(2);

%% make some plots
if showPlot
    figure;
    subplot(1,2,1);
    plot(binEdges(2:end), respA); hold on;
    plot(binEdges(2:end), respB); legend({'respA' 'respB'});
    axis square; title('Response distributions');
    
    subplot(1,2,2);
    plot([0 1],[0 1]); hold on
    plot(fa,hit,'color','r', 'linewidth', 2);
    axis square; title(['AUC = ' num2str(AUC)]); xlabel('FAs'); ylabel('Hits');
end