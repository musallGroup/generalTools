function cMovie = makeMovieFromBinary(cPath, cFile, nrFrames)

% cPath = '\\Naskampa.kampa-10g\lts2\2P-PuffyPenguin-Jülich\320\20250122\suite2p\plane1';
% cFile = 'data.bin';

imgRes = [512, 512];
% nrFrames = 700;
% frameSmooth = 50;


%%
useFile = fullfile(cPath,cFile);
cID = fopen(useFile);

cMovie = nan([imgRes, nrFrames], 'single');
for iFrames = 1 : nrFrames
    cImg  = fread(cID, prod(imgRes), 'int16=>int16');
    cMovie(:,:,iFrames) = reshape(cImg, imgRes);
    
    loopReporter(iFrames, nrFrames, 10)
end

fclose(cID);

% smooth over frames
% cMovieSm = smoothCol(cMovie, 3, frameSmooth, 'box');
% compareMovie(cMovieSm)


