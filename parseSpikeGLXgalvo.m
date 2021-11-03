function frameStarts = parseSpikeGLXgalvo(slowGalvo, minGalvoDiff)
% frameStarts = parseSpikeGLXgalvo(slowGalvo)
% 
% Identify when frame starts were relative to the analog channels, by
% parsing the slow galvo channel to find turnarounds.

%% Extract the part of the signal where the voltage is changing
% (clipping off any static portions at the beginning or end)
changes = slowGalvo(1:end-1) ~= slowGalvo(2:end);
firstReal = find(changes, 1);
lastReal = find(changes, 1, 'last');
slowGalvo = slowGalvo(firstReal:lastReal);

%% Find possible frame starts
galvoDiff = diff(slowGalvo);

% Minimum change in slow galvo position we'll consider a normal,
if ~exist('minGalvoDiff', 'var') || isempty(minGalvoDiff)
%     minGalvoDiff = 2^16 * 0.01; %10V is 2^16, so the 0.01 sets the threshold at 0.1V.
    minGalvoDiff = std(single(galvoDiff)) * 4; % set a threshold at 4 SDUs of the differential
end

galvoChanges = (galvoDiff < -minGalvoDiff);
db = diff([0; single(galvoChanges(:))]);
frameStarts = find(db<0);
frameStarts = frameStarts + firstReal - 1;