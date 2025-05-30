function VideoData = loadVideoData(inputPath)
%make sure there is a file separator at the end of the path
if inputPath(end) ~= filesep
    inputPath = [inputPath, filesep];
end
matFile = dir([inputPath '*mergeSingleCam*lowD.mat']);
% Load the .mat file
VideoData = load([inputPath matFile.name]);
end
