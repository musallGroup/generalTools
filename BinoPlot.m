function mInfo = BinoPlot(data,Groups,UseBars,FitOn,alpha,mType,Est,aColor,StartFit,EndFit)
% Function to plot binomial data and provide basic fitting if needed.
% BinoPlot will use the provided data to create either an errorbar or
% barplot with errorbars. Fits are either linear (standard) or sigmoid
% (e.g. for behavioral tuning curves). Only data input has to be provided, 
% other inputs are optional. The plotted data are percent values.
%
% Usage: mInfo = BinoPlot(data,Groups,UseBars,FitOn,alpha,mType,Est,aColor,StartFit,EndFit)
% Inputs:
% data: Data can either be a vector or matrix of zeros and ones or already
%       counted values. 
%       In case of digital data, every collumn is a sequence of outcomes
%       with 1 being a positve outcome.
%       In case of counted data, the first collumn is the amount of
%       positive outcomes and the second collumn is the absolute amount of
%       trials.
% Groups: x-values for data input. If empty, the default cause is linear
%         steps of 1.
% UseBars: Determines whether to produce a errorbar or barplot.
% FitOn: Determines whether data should be fitted or not.
% alpha: Determines the size of the confidence intervals. Errorbars show
%        confidence intervals of the size 100-alpha %. For example, an 
%        alpha of 5% will produce errorbars showing 95% confidence 
%        intervals (default case).
% mType: Type of model for fitting the data. Possible inputs are 'linear'
%        (default) or 'sigmoidal'.
% Est: Model estimates that be used for sigmoidal fitting. Est is a 1x4
%      vector with Est(1) = lower fit limit (on the y-axis), Est(2) = upper
%      fit limit, Est(3) = occurence of the inflection point (on the x-axis) 
%      and Est(4) = slope of the fit (a value of 1 indicates that the fit 
%      will go from its lower to the upper limit in 10 steps)  
% aColor: Color of the plot and fitting curve. Default is green ('g').
% StartFit: Start point from where the fit is plotted.
% EndPoint: End point to where the fit is plotted.
%
% Output:
% mInfo: Object from fitting that contains information about the fitting 
%        function and the applied coefficients + 95% confidence bounds.
%
% 
% Examples: 
%   data = cat(2,[0;20;60;116;232;339;411;418;415],[504;515;493;515;499;503;500;493;508]);
%   Groups = 10:10:90;
%   subplot(2,2,1); 
%   BinoPlot(data,Groups,1,0,5,[],[],'r');title('Barplot') % for barplot without fit
%   subplot(2,2,2); 
%   sigInfo = BinoPlot(data,Groups,0,1,5,'sigmoid',[],'r',0,100);title('Sigmoidal Fit') % for errorbar plot with sigmoidal fit
% 
%   data = cat(2,[198;212;201;204;220;194;211;215;218],[504;515;493;515;499;503;500;493;508]);
%   subplot(2,2,3);
%   BinoPlot(data,Groups,1,0,5,[],[],'g');ylim([0 100]); title('Barplot') % for barplot without fit
%   subplot(2,2,4); 
%   linInfo = BinoPlot(data,Groups,0,1,5,'linear',[],'g',0,100);ylim([0 100]);title('Linear Fit') % for errorbar plot with linear fit
%
% smusall 2014/10/27

%% Define default values
Linewidth = 2;      % Default linewdith in points
Markersize = 9;     % Default Markersize in points
Barwidth = 0.5;     % Default width of errorbars (should be <1)
StepNr = 100;       % Default nr. of datapoints of the fitted curve. More steps increase fit smoothness.

%% Check basic input variables
if exist('aColor','var')==0 || isempty(aColor)
     aColor = 'g';       % Default plot color
end

if exist('alpha','var')==0 || isempty(alpha)
    CI=[0.025 0.975];   % 95% confidence intervals (default, same as alpha=5 as input)
else
    CI = alpha/200;CI(2)=1-CI;
end

if exist('FitOn','var')==0 || isempty(FitOn)
     FitOn = false;       % Default is no fitting
end

if exist('UseBars','var')==0 || isempty(UseBars)
     UseBars = false;       % Default is no bars
end

%% compute plotvalues
if any(any(data~=0 & data~=1))  % counted input (counted trials where the first collumn is the amount of positive outcomes, the second collumn is the amount of trials)
    Trials = data(:,2)';
    Hits = data(:,1)'./Trials;    
else                                %logical input (digitally encoded trials where every collumn is a sequence of trials and true values encode positive outcomes)
    Hits = sum(data)./size(data,1);
    Trials = repmat(size(data,1),1,length(Hits));
end

for iSeq = 1:length(Hits)
    Error(:,iSeq)=(binoinv(CI,Trials(iSeq),Hits(iSeq))./Trials(iSeq))*100; %compute errorbar values
end
Hits = Hits*100;

if exist('Groups','var')==0 || isempty(Groups)
    Groups = 1:iSeq; 
end

%% plot fit and data
if ~ishold
    check=true;else check=false; %check hold status and restore after plotting
end

if FitOn
    %% assign fitting inputs and steps for ploting the fit   
    if exist('StartFit','var')==0 || isempty(StartFit)
        StartFit = Groups(1);
    end
    
    if exist('EndFit','var')==0 || isempty(EndFit)
        EndFit = Groups(end);
    end    
    
    if exist('mType','var')==0 || isempty(aColor)
        mType = 'linear';       % Default model type
    end
    
    Steps=StartFit:(EndFit-StartFit)/(StepNr-1):EndFit;

    if exist('Est','var')==0 || isempty(Est) || length(Est)~=4
        %standard estimates for sigmoid fit function: Assumes that first and last values are lower and upper limit, inflection point is about in the middle of the distribution and the slope increases evenly over all datapoints   
        Est = [Hits(1) Hits(end) Groups(floor(length(Groups)/2)) (max(Groups)-min(Groups))/10]; 
    end
    
    if strcmpi(mType,'linear')
        %% produce linear fit
        p = polyfit(Groups,Hits,1);
        f = @(p,x) p(1)*x + p(2);
        mInfo=fit(Groups',Hits','a*x + b','start',p);
    elseif strcmpi(mType,'sigmoid')
        %% produce sigmoidal fit based on given estimates
        f = @(p,x) p(1) + p(2) ./ (1 + exp(-(x-p(3))/p(4)));
        p = nlinfit(Groups,Hits,f,[Est(1) Est(2) Est(3) Est(4)]);
        mInfo=fit(Groups',Hits','a + b ./ (1 + exp(-(x-m)/s))','start',Est);
    else
        error('Wrong input for type of fit - Fit has to be either linear or sigmoid')
    end
    plot(Steps,f(p,Steps),'color',aColor,'Linewidth',Linewidth);hold on; % plot fit
end

%% plot data
if FitOn && ~UseBars
    errorbar(Groups,Hits,Hits-Error(1,:),Error(2,:)-Hits,'o','color',aColor,'MarkerEdgeColor','k','MarkerFaceColor',aColor,'Linewidth',Linewidth)
elseif ~FitOn && ~UseBars
    errorbar(Groups,Hits,Hits-Error(1,:),Error(2,:)-Hits,'-o','color',aColor,'MarkerEdgeColor','k','MarkerFaceColor',aColor,'Linewidth',Linewidth,'Markersize',Markersize)
elseif UseBars
    bar(Groups,Hits,Barwidth,'EdgeColor','k','FaceColor',aColor,'Linewidth',Linewidth);hold on;
    errorbar(Groups,Hits,Hits-Error(1,:),Error(2,:)-Hits,'o','color','k','MarkerEdgeColor','k','MarkerFaceColor',aColor,'Linewidth',Linewidth)
end    

if check
    hold off;
end