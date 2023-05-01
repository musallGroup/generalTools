function [A, tau, fun] = exponentialFit(dataIn)
% fit data with exponential function and return initial ampltiude A and tau


t = (1:length(dataIn))'; %time axis in samples

fun = @(b,x) b(1) * exp(-x / b(2)); %defome exponential function. b(1) is A and b(2) is tau.

opts = optimoptions('lsqcurvefit', 'Display', 'off'); %supress outputput
f = lsqcurvefit(fun, [dataIn(1), length(dataIn) / 2], t, dataIn, [], [], opts); %get the fit

A = f(1);
tau = f(2);