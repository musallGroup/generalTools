function convertMJ2(cFile,tFile)
%code to convert mj2 files into mp4. cFile is the path to the source mj2
%file, tFile is the path to the target file. if tFIile is not given, it
%will be the same as 'cFile' and just change the file extension.

cVid = VideoReader(cFile);
nrFrames = (cVid.Duration * cVid.FrameRate);

if ~exist('tFile', 'var')
    tFile = strrep(cFile, '.mj2', '');
end

v = VideoWriter(tFile, 'MPEG-4'); %save as compressed video file
v.Quality = 100;
open(v);

for iFrames = 1 : 500 : nrFrames
    
    cIdx = [iFrames min(iFrames + 499, nrFrames)];
    rawData = read(cVid, cIdx);
    
    writeVideo(v,rawData);
end
close(v);