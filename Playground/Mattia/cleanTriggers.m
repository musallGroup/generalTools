function VideoData = cleanTriggers(VideoData, SessionData)

% find the indeces of the valid trials
idx = find([SessionData.Response_left] ~= -1 & ...
    [SessionData.auto_reward] ~= 1 & ...
    [SessionData.both_spouts] == 1);
% only keep the respective triggers
VideoData.vidDigitalTrigs = VideoData.vidDigitalTrigs(idx); %#ok<*FNDSB>