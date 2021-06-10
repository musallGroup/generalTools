function convertMJ2(cFile,tFile, lowThresh, highThresh, gammaVal, imScale, imgSmooth)
%code to convert mj2 files into mp4. cFile is the path to the source mj2
%file, tFile is the path to the target file. if tFIile is not given, it
%will be the same as 'cFile' and just change the file extension.
%'imScale' is a scaling factor that can be used to change the resolution
%of the video.

cVid = VideoReader(cFile);
nrFrames = (cVid.Duration * cVid.FrameRate);

if ~exist('tFile', 'var')
    tFile = strrep(cFile, '.mj2', '');
end

if ~exist('lowThresh', 'var') || isempty(lowThresh)
    lowThresh = 0.1;
end

if ~exist('highThresh', 'var') || isempty(highThresh)
    highThresh = 0.5;
end

if ~exist('gammaVal', 'var') || isempty(gammaVal)
    gammaVal = 0.5;
end

if ~exist('imScale', 'var') || isempty(imScale)
    imScale = 1;
end

if ~exist('imgSmooth', 'var') || isempty(imgSmooth)
    imgSmooth = false;
end

v = VideoWriter(tFile, 'MPEG-4'); %save as compressed video file
v.Quality = 100;
open(v);

tic
batchSize = 1000;
for iFrames = 1 : batchSize : nrFrames
    
    cIdx = [iFrames min(iFrames + batchSize - 1, nrFrames)];
    rawData = read(cVid, cIdx);
    rawData = mat2gray(rawData);
    rawSize = size(rawData);
    newRawData = zeros([rawSize(1:2).*imScale rawSize(3:end)]);
        
    for x = 1 : size(rawData,4)
        
        if imScale ~= 1
            newRawData(:,:,:,x) = imresize(rawData(:,:,:,x),imScale); %change resolution
        else
            newRawData(:,:,:,x) = rawData(:,:,:,x);
        end
        
        if imgSmooth
            newRawData(:,:,:,x) = arrayFilter(newRawData(:,:,:,x),3*imScale,imScale,2);
        end
        newRawData(:,:,:,x) = imadjust(newRawData(:,:,:,x),[lowThresh; highThresh],[], gammaVal); %improve contrast
    end
    
    writeVideo(v,newRawData);
    
    if rem(cIdx(end), batchSize*10) < batchSize+1
        fprintf('%g percent complete - %g/%g frames\n', cIdx(end) / nrFrames *100, cIdx(end), nrFrames);
        toc
    end
end
close(v);
clear cVid v