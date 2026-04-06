function keep(varargin)
% keep - clear all workspace variables except the specified ones.
% Usage: keep var1 var2 ...
%   equivalent to: clearvars -except var1 var2 ...
%
% Example:
%   keep fPath opts   % keeps fPath and opts, clears everything else

if isempty(varargin)
    evalin('caller', 'clearvars');
else
    evalin('caller', ['clearvars -except ' strjoin(varargin, ' ')]);
end
