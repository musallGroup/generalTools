% directory of processed image
serverPath = '\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\Triple*';
SavePath = 'E:\Histology_NeuronDistributionALM\';
slicePath = '*.mat';
% conversionFactor = 0.5681821; % conversion factor um/pixel
allSlices = dir([serverPath]);

%% Load Data

for iSlice = 1:length(allSlices)
    
    blueFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Blue\*.mat']);
    blueData = load(strcat(blueFile.folder, '\', blueFile.name) ).masks;
    redFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Red\*.mat']);
    redData = load(strcat(redFile.folder, '\', redFile.name) ).masks;
    greenFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Green\*.mat']);
    greenData = load(strcat(greenFile.folder, '\', greenFile.name) ).masks;
      
end
