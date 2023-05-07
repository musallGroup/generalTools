function [f, fun] = exponentialFit(dataIn, expType)
% fit data with exponential function and return initial ampltiude A and tau

if ~exist('expType', 'var') || isempty(expType)
    expType = 'regular';
end

t = (1:length(dataIn))'; %time axis in samples

if strcmpi(expType, 'regular')
    fun = @(b,x) b(1) * exp(-x / b(2)); %defome exponential function. b(1) is A and b(2) is tau.
    x0(1) = max(dataIn); % Amplitude of the exponential decay
    x0(2) = mean(t); % Initial guess for the time constant
    lb = [0, 0];
    ub = [inf, inf];

elseif strcmpi(expType, 'double')
    fun = @(b,x) b(1) * exp(-b(2) * x) + b(3) * exp(b(2) * x);
    x0(1) = max(dataIn); % Amplitude of the first exponential term
    x0(2) = 1 / length(dataIn); % Decay rate of the first exponential term
    x0(3) = min(dataIn); % Amplitude of the second exponential term
    x0(4) = 1 / length(dataIn); % Decay rate of the second exponential term
    lb = [-inf, 0];
    ub = [inf, inf];
end
   
opts = optimoptions('lsqcurvefit', 'Display', 'off'); %supress outputput
f = lsqcurvefit(fun, x0, t, dataIn, [], [], opts); %get the fit