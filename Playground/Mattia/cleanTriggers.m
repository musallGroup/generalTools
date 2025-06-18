function VideoData = cleanTriggers(VideoData, SessionData, keep)

% find the indeces of the valid trials
idx = find([SessionData.Response_left] ~= -1 & ...
    [SessionData.auto_reward] ~= 1 & ...
    [SessionData.both_spouts] == 1);
% only keep the respective triggers but adjust depending on which variable
% has the correct amount of triggers
if keep == 1
    VideoData.vidDigitalTrigs = VideoData.vidDigitalTrigs(idx); %#ok<*FNDSB>
elseif keep == 2
    VideoData.vidDigitalTrigs = VideoData.useTrigs{1, 1};
    VideoData.vidDigitalTrigs = VideoData.vidDigitalTrigs(idx); %#ok<*FNDSB>
end