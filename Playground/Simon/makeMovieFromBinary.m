function makeMovieFromBinary(cPath, cFile)

% cPath = '\\Naskampa.kampa-10g\lts2\2P-PuffyPenguin-Jülich\320\20250122\suite2p\plane1';
% cFile = 'data.bin';

imgRes = [512, 512];
nrFrames = 1000;
frameSmooth = 30;



%%
useFile = fullfile(cPath,cFile);
cID = fopen(useFile);

cMovie = nan([imgRes, nrFrames], 'single');
for x = 1 : 2
for iFrames = 1 : nrFrames
    cImg  = fread(cID, prod(imgRes), 'int16=>int16');
    cMovie(:,:,iFrames) = reshape(cImg, imgRes);
    
    loopReporter(iFrames, nrFrames, 10)
end
end

% smooth over frames
cMovieSm = smoothCol(cMovie, 3, frameSmooth, 'box');

compareMovie(cMovieSm)

fclose(cID);

