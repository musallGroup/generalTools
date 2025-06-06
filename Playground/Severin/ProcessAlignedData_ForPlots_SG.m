%% Load Atlas Data and Processed Images
minAreaSizeforPlot = 100; %number of pixels in a given area before its plotted on the histo image
colorChannel = 1; %this would be red, green, blue for 1,2,3

% directory of processed image
serverPath = 'E:\Histology\SOM exampels\KO_V1_SC\processed';
localSavePath = 'E:\Histology\SOM exampels\KO_V1_SC\processed';
serverFolder = '\transformations'; %path to transofrmed images
Image_folder = fullfile(serverPath, serverFolder);
Save_folder = fullfile(localSavePath, serverFolder);


% directory of AtlasData
Atlas_folder = 'E:\Histology\'; %path to saved AtlasData
Atlas_file_name = 'AtlasData';
Save_name = 'KO_V1_SC';
Save_name_cumulative = 'SOM_';
Save_name_fig = 'HistoFigure_';
% Save_folder = '\\Fileserver\Allgemein\transfer\for Irene\data\ALM_SC_04_tifs\C5_TL_GFP\processed\transformations\'; %path to folder to save the analyzed data
allImages = dir(fullfile(Image_folder,'*.tif'));
allTransform = dir(fullfile(Image_folder,'*_processed_transform_data.mat'));


%% only use files where both tif and transformed matlab data exist
% allImages = dir(fullfile(Image_folder,'*.tif'));
% allTransform = dir(fullfile(Image_folder,'*_processed_transform_data.mat'));
% % fileName = allTransform.name;
% % Define a function to extract the numbers from file names using textscan
% extractNumber = @(fileName) textscan(fileName, '%s%s%d', 1, 'Delimiter', '-');
% imgNumbers = cellfun(@(c) c{3}, cellfun(extractNumber, {allImages(:).name}, 'UniformOutput', false));
% matNumbers = cellfun(@(c) c{3}, cellfun(extractNumber, {allTransform(:).name}, 'UniformOutput', false));
% 
% imUseIdx = ismember(imgNumbers, matNumbers); %check for images that have no transform
% matUseIdx = ismember(matNumbers, imgNumbers(imUseIdx)); %check for transforms that have no images
% 
% % only use correct files
% allImages = allImages(imUseIdx);
% allTransform = allTransform(matUseIdx);

%% load atlas data
full_path_atlas = fullfile(Atlas_folder, Atlas_file_name + ".mat");
AtlasData = load(full_path_atlas);
av = AtlasData.allData.av;
st = AtlasData.allData.st;
tv = AtlasData.allData.tv;
    
%% run over slices
h = figure;
for iSlice = 1:length(allImages)

    %Transform_file_name = 'Composite9_GFP-tdTomato_processed_transform_data';
    Transform_file_name = allTransform(iSlice).name;
    full_path_file = fullfile(Image_folder, Transform_file_name);
    ImageData = load(full_path_file);
    current_slice = ImageData.save_transform.allen_location{1};

    % directory of Transformed Image
    %Transformed_image = imread('Y:\Histology_Musall\Histology_Irene\Moritz\M133_Tiff\processed3\transformations\Composite13_GFP-tdTomato_processed_transformed.tif');
    Transformed_image = imread(fullfile(Image_folder, allImages(iSlice).name));
    subplot(1,3,1); cla;
    imshow(Transformed_image); axis image;
    title(['Fluorescence; Current slice: ' num2str(current_slice)]); axis image;

    subplot(1,3,2); cla;
    imshow(Transformed_image); axis image; hold on;
    title(['Fluorescence+Outlines; Current slice: ' num2str(current_slice)]); axis image;

    %% Find Histology Plane into the AtlasData and Calculate mean fluorescence within each Brain Region (ROI)
    av = AtlasData.allData.av;
    st = AtlasData.allData.st;
    tv = AtlasData.allData.tv;

    subplot(1,3,3); cla;
    imagesc(squeeze(av(current_slice,:,:)));
    title(['Allen slice ' num2str(current_slice)]); axis image;

    %% check regions
    RegionsID = (unique(av(current_slice,:,:)));
    meanFluorescence = zeros(length(RegionsID), size(Transformed_image,3));
    regionId = zeros(length(RegionsID),1);
    regionName = strings(length(RegionsID),1);
    regionAcr = strings(length(RegionsID),1);

    concatenatedTable = [];
    for cID = 1: length(RegionsID)

        locID = squeeze(av(current_slice,:,:)) == RegionsID(cID); %get mask for current area
%         cData = arrayShrink(Transformed_image, ~locID, 'merge'); %this function extracts the pixels from all channels in the current area
        cData = Transformed_image(:,:,1) -  Transformed_image(:,:,2); %subtract green channel from red to remove brightfield component
        meanFluorescence(cID) = mean(cData(locID), "all");
        regionName(cID) = st.name{RegionsID(cID)};
        regionAcr(cID) = st.acronym{RegionsID(cID)};
        regionId(cID) = RegionsID(cID);

        % show area outlines on fluorescent image
        subplot(1,3,2); hold on;
        a = bwboundaries(locID); %outline of selected area
        for x = 1 : length(a)
            if size(a{x},1) > minAreaSizeforPlot
                plot(smooth(a{x}(:,2),10),smooth(a{x}(:,1),10),'w', 'linewidth', 0.1)
            end
        end
    end
    drawnow;
    if ~exist(Save_folder, 'dir')
        mkdir(Save_folder);
    end
    fluoTable = table(regionId,regionAcr,regionName,meanFluorescence);
    save(fullfile(Save_folder, Save_name + string(current_slice) + ".mat"), "fluoTable");

    % save figure as jpg
    set(h, 'Color', 'w');
    set(h, 'InvertHardcopy', 'off');
    saveas(h, fullfile(Save_folder, Save_name + string(current_slice) + ".fig"));
    fprintf('Current slice %i/%i\n', iSlice, length(allImages))

    % pause; %you can use this is if you want to look at timages and
    % confirm with a button press
end







%% Create a table for concatenated fluorescence values
Results_folder = Save_folder;
if ~exist('AtlasData', 'var')
    Atlas_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
    Atlas_file_name = 'AtlasData';
    Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
    AtlasData = load(Atlas_FullPath_File);
end
av = AtlasData.allData.av;
st = AtlasData.allData.st;
tv = AtlasData.allData.tv;

allFiles = dir(fullfile(Results_folder,[Save_name '*.mat']));
numFiles = size(allFiles,1);

AllRegionID = unique(AtlasData.allData.st.sphinx_id);

fluorescenceMatrix = cell(length(AllRegionID), numFiles+1);
fluorescenceMatrix(:,1) = st.name;
fluorescenceMatrix(:,2:numFiles+1) = {NaN};
idx = zeros(1,numFiles);

% Loop through each file
for iFile = 1:numFiles
    % Load the fluorescence table
    tableFileName = fullfile(Results_folder, allFiles(iFile).name);
    FluorescenceData = load(tableFileName);
    fluoTable = FluorescenceData.fluoTable;
    allRegions = fluoTable.regionName;
    genName = split(allFiles(iFile).name, '_');
    sliceNb = split(genName{2}, '.');
    idx(iFile) = str2double(sliceNb{1});
    for iReg = 1:length(allRegions)
        regionName = allRegions(iReg);
        regionRow = find(ismember(fluorescenceMatrix(:,1),regionName));
        fluorescenceMatrix(regionRow,iFile+1) = {fluoTable.meanFluorescence(strcmpi(fluoTable.regionName,regionName), :)};
    end
end
save(fullfile(Results_folder, [Save_name_cumulative '.mat']), 'fluorescenceMatrix', 'idx');




%% Get fluorescence Traces for a given area

% Need to change this in order to apply it to several datasets

Results_folder = 'C:\Users\abourachid\histology_Julich_retro\2870\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);


% Striatum = {'Caudoputamen'};
Tn.Thalamus = {"Thalamus"};
Tn.ThalamicVentral = {"Ventral anterior-lateral complex of the thalamus", "Ventral medial nucleus of the thalamus", "Ventral posterolateral nucleus of the thalamus", "Ventral posteromedial nucleus of the thalamus"};
Tn.ThalamicPosterior = {"Lateral posterior nucleus of the thalamus", "Posterior complex of the thalamus"};
Tn.ThalamicCentral = { "Lateral dorsal nucleus of thalamus", "Intermediodorsal nucleus of the thalamus", "Mediodorsal nucleus of thalamus",...
    "Nucleus of reuniens", "Rhomboid nucleus", "Central medial nucleus of the thalamus", "Paracentral nucleus","Central lateral nucleus of the thalamus"};
Tn.ThalamicParaventricular = {"Paraventricular nucleus of the thalamus"};
Tn.ThalamicInhibitory = {"Reticular nucleus of the thalamus"};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsTn = fieldnames(Tn);
for iTnRegion = 1:length(fieldsTn)
    figure;
    Tn_Nuclei = Tn.(fieldsTn{iTnRegion});
    for iNucleus = 1:numel(Tn_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Tn_Nuclei{iNucleus}));

        if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(Tn_Nuclei{1:iNucleus});
            xlim([0 65])
%             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsTn{iTnRegion})));
end



%% sc
SC.Sensory = {'"Superior colliculus sensory related"', '"Superior colliculus optic layer"'};
SC.Motor = {'"Superior colliculus motor related"', '"Superior colliculus motor related deep gray layer"', '"Superior colliculus motor related deep white layer"', '"Superior colliculus motor related intermediate white layer"', '"Superior colliculus motor related intermediate gray layer"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsSC = fieldnames(SC);
for iSCRegion = 1:length(fieldsSC)
    figure;
    SC_Nuclei = SC.(fieldsSC{iSCRegion});
    for iNucleus = 1:numel(SC_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), SC_Nuclei{iNucleus}));

        if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(SC_Nuclei{1:iNucleus});
            xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('SC Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsSC{iSCRegion})));
end

%% test Motor Cortex

Results_folder = 'C:\Users\abourachid\histology_Julich_retro\2870\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);
Motor.Cortex = {'"Secondary motor area layer 1"', '"Secondary motor area layer 2/3"', '"Secondary motor area layer 5"', '"Secondary motor area layer 6a"', '"Secondary motor area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsMotor = fieldnames(Motor);
for iMotorRegion = 1:length(fieldsMotor)
    figure;
    Motor_Nuclei = Motor.(fieldsMotor{iMotorRegion});
    for iNucleus = 1:numel(Motor_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Motor_Nuclei{iNucleus}));

        if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(Motor_Nuclei{1:iNucleus});
            xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Secondary Motor Cortex Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsMotor{iMotorRegion})));
end
%% %% test Somatosensory Cortex

Results_folder = 'C:\Users\abourachid\histology_Julich_retro\2870\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);
% Somatosensory.Cortex = {"Primary somatosensory area barrel field layer 1", "Primary somatosensory area barrel field layer 2/3", "Primary somatosensory area barrel field layer 4", "Primary somatosensory area barrel field layer 5", "Primary somatosensory area barrel field layer 6a", "Primary somatosensory area barrel field layer 6b"};
Somatosensory.Cortex = {'"Primary somatosensory area barrel field layer 1"', '"Primary somatosensory area barrel field layer 2/3"',...
    '"Primary somatosensory area barrel field layer 4"', '"Primary somatosensory area barrel field layer 5"', '"Primary somatosensory area barrel field layer 6a"', '"Primary somatosensory area barrel field layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsSomatosensory = fieldnames(Somatosensory);
for iSomatosensoryRegion = 1:length(fieldsSomatosensory)
    figure;
   Somatosensory_Nuclei = Somatosensory.(fieldsSomatosensory{iSomatosensoryRegion});
    for iNucleus = 1:numel(Somatosensory_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Somatosensory_Nuclei{iNucleus}));

         if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(Somatosensory_Nuclei{1:iNucleus});
            xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Somatosensory Cortex barrel field area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsSomatosensory{iSomatosensoryRegion})));
end
%% Test Anterolateral visual area

Results_folder = 'C:\Users\abourachid\histology_Julich_retro\2869\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

AntVisual.area = { '"Anterolateral visual area layer 1"', '"Anterolateral visual area layer 2/3"', '"Anterolateral visual area layer 4"',...
    '"Anterolateral visual area layer 5"', '"Anterolateral visual area layer 6a"', '"Anterolateral visual area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsAntVisual = fieldnames(AntVisual);
for iAntVisualRegion = 1:length(fieldsAntVisual)
    figure;
    AntVisual_Nuclei = AntVisual.(fieldsAntVisual{iAntVisualRegion});
    for iNucleus = 1:numel(AntVisual_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), AntVisual_Nuclei{iNucleus}));

         if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(AntVisual_Nuclei{1:iNucleus});
            xlim([0 65])
%            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anterolateral Visual area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of S1 projections into ',(fieldsAntVisual{iAntVisualRegion})));
end
%% Test Anterior_Cingulate Cortex 


Results_folder = 'C:\Users\abourachid\histology_Julich_retro\2870\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
AntCingulate.dorsal = { '"Anterior cingulate area dorsal part layer 1"', '"Anterior cingulate area dorsal part layer 2/3"', '"Anterior cingulate area dorsal part layer 5"',...
    '"Anterior cingulate area dorsal part layer 6a"', '"Anterior cingulate area dorsal part layer 6b"'};
AntCingulate.ventral = { '"Anterior cingulate area ventral part layer 1"', '"Anterior cingulate area ventral part layer 2/3"', '"Anterior cingulate area ventral part layer 5"', '"Anterior cingulate area ventral part layer 6a"', '"Anterior cingulate area ventral part layer 6b"'};
fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsAntCingulate = fieldnames(AntCingulate);
for iAntCingulateRegion = 1:length(fieldsAntCingulate)
    figure;
   AntCingulate_Nuclei = AntCingulate.(fieldsAntCingulate{iAntCingulateRegion});
    for iNucleus = 1:numel(AntCingulate_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), AntCingulate_Nuclei{iNucleus}));

         if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);
            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values
                cData = values_cell{iValue}; %current fluoresence data from channel of interest
                if any(isnumeric(cData) & ~isnan(cData))
                    values(iValue) = cData(colorChannel);
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(AntCingulate_Nuclei{1:iNucleus});
            xlim([0 65])
 %           ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anterior Cingulate Cortex Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsAntCingulate{iAntCingulateRegion})));
end



%% Loop on all brains to average
stepSize = 10;
sliceSteps = 1: stepSize : size(av,1);

histologyPath = 'E:\Histology_AnterogradeALM_Plots\';
% subFolder = '\**\';
fileNames = 'ALM_SC_*'; 

if ~exist('AtlasData', 'var')
    Atlas_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
    Atlas_file_name = 'AtlasData';
    Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
    AtlasData = load(Atlas_FullPath_File);
end

av = AtlasData.allData.av;
st = AtlasData.allData.st;
tv = AtlasData.allData.tv;

AllRegionID = unique(AtlasData.allData.st.sphinx_id);

% Get all subfolders
allBrains = dir([histologyPath fileNames]);

% Initialize fluorescenceAvg
fluorescenceAvg = NaN(length(AllRegionID), length(sliceSteps));
fluorescenceMax = fluorescenceAvg;
fluorescenceMin = fluorescenceAvg;
fluorescenceSEM = fluorescenceAvg;

% Loop through each subfolder
for iBrain = 1:length(allBrains)
      brainID = allBrains(iBrain).name;


    if allBrains(iBrain).isdir && ~strcmp(allBrains(iBrain).name, '.') && ~strcmp(allBrains(iBrain).name, '..')
        currentBrainFolder = fullfile(histologyPath, allBrains(iBrain).name);
        
        % Load the data
        currentFilePath = fullfile(currentBrainFolder, 'FluorescenceMatrixCumulative.mat');
        loadedData = load(currentFilePath);
        
        % Assign the loaded data to the respective variables
        fluorescenceMatrixes.(allBrains(iBrain).name) = loadedData.fluorescenceMatrix;
        idxSlide.(allBrains(iBrain).name) = loadedData.idx;
    end
end

for iReg = 1:length(AllRegionID)
    Cnt = 0;
    for iSlide = sliceSteps
        Cnt = Cnt + 1;
        fluoVal = [];
        for iBrain = 1:length(allBrains)
            brainID = allBrains(iBrain).name;
            % If the slide is in this brain, add the value
            useIdx = ismember(idxSlide.(brainID), iSlide + ((1 : stepSize)-1)); %slices to use
            if any(useIdx)
                
                %check that number of channels are consistent. Can be an issues because of nans being set as a single number.
                cData = fluorescenceMatrixes.(brainID)(iReg,find(useIdx)+1);
            
                [~, numChans] = cellfun(@size, cData);
                if length(unique(numChans)) ~= 1
                    cData = cData(numChans > 1);
                end
                cData = cat(1, cData {:});
                
                
                % collect data from slices
                if size(cData,2) > 1 %more than one channel present, use colorChannel to select
                    fluoVal = cat(1,fluoVal,cData(:, colorChannel));
                else
                    fluoVal = cat(1,fluoVal,cData);
                end
            end
        end
        
        if ~isempty(fluoVal)
            fluorescenceAvg(iReg, Cnt) = mean(fluoVal); % Do the mean across brains
            fluorescenceSEM(iReg, Cnt) = sem(fluoVal); % Do the sem across brains
            fluorescenceMax(iReg, Cnt) = max(fluoVal);
            fluorescenceMin(iReg, Cnt) = min(fluoVal);
        end
    end
end

%% Get fluorescence Traces for a given area
% Striatum = {'Caudoputamen'};
Tn.Thalamus = {"Thalamus"};
% Tn.ThalamicVentral = {"Ventral anterior-lateral complex of the thalamus", "Ventral medial nucleus of the thalamus", "Ventral posterolateral nucleus of the thalamus", "Ventral posteromedial nucleus of the thalamus"};
% Tn.ThalamicPosterior = {"Lateral posterior nucleus of the thalamus", "Posterior complex of the thalamus"};
% Tn.ThalamicCentral = { "Lateral dorsal nucleus of thalamus", "Intermediodorsal nucleus of the thalamus", "Mediodorsal nucleus of thalamus",...
%     "Nucleus of reuniens", "Rhomboid nucleus", "Central medial nucleus of the thalamus", "Paracentral nucleus","Central lateral nucleus of the thalamus"};
% Tn.ThalamicParaventricular = {"Paraventricular nucleus of the thalamus"};
% Tn.ThalamicInhibitory = {"Reticular nucleus of the thalamus"};

Tn.ALM = {"Ventral medial nucleus of the thalamus", "Mediodorsal nucleus of thalamus"};
plotColor = ['r', 'b', 'k', 'y', 'm', 'c', 'g', 'w'];

fieldsTn = fieldnames(Tn);
for iTnRegion = 1:length(fieldsTn)
    figure;
    Tn_Nuclei = Tn.(fieldsTn{iTnRegion});
    clear cLine
    for iNucleus = 1:numel(Tn_Nuclei)
        idNucleus = find(strcmpi(st.name(:), Tn_Nuclei{iNucleus}));
        index = st.sphinx_id(idNucleus);

        if ~isempty(index)

            cIdx = ~isnan(fluorescenceAvg(index, :));
            xVals = sliceSteps(cIdx);
            cData = fluorescenceAvg(index, cIdx);
            semData = fluorescenceSEM(index, cIdx);
            
            hold on;
            cLine(iNucleus) = errorshade(xVals, cData(:), semData(:), semData(:), plotColor(iNucleus), 0.2, 3);
            
            
%             pause
%             valuesSEM = fluorescenceSEM(index, 2:end);
%             valuesMax = fluorescenceMax(index, 2:end);
%             valuesMin = fluorescenceMin(index, 2:end);

%             num_values = numel(values_cell);
%             values = NaN(1, num_values); 
% 
%             for iValue = 1:num_values
% 
%                 if isnumeric(values_cell(iValue)) && ~isnan(values_cell(iValue))
% 
%                     values(iValue) = values_cell(iValue);
%                 end
%             end

%             plot(find(~isnan(values)), smooth(values(~isnan(values))));
%             legendNuclei = cell(1, iNucleus*2);
%             legendNuclei(1:2:end) = {Thalamic_Nuclei{1:iNucleus}};
%             for iLeg = 2:2:iNucleus*2
%                 legendNuclei(iLeg) = {"Error "+ Thalamic_Nuclei{iLeg/2}};
%             end
%             
%             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
%             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
%             hold on;

        end
    end
    niceFigure;
    legend(cLine, Tn_Nuclei);
%     xlim([0 size(tv, 1)]);
    xlim([540 980]);
    ylim([0 3.5]);
    set(gca, 'ylim', [0 2]);
    set(gca, 'ytick', 0:0.4:2);
            
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsTn{iTnRegion})));
end


%% Get fluorescence Traces for the collicular area
% Define the SC structures
% SC.Sensory = {'"Superior colliculus sensory related"', '"Superior colliculus optic layer"'};
SC.Motor = {'"Superior colliculus motor related"','"Superior colliculus motor related deep gray layer"', '"Superior colliculus motor related deep white layer"','"Superior colliculus motor related intermediate white layer"', '"Superior colliculus motor related intermediate gray layer"'};
% SC.Motor = {'"Superior colliculus motor related deep gray layer"'};

plotColor = ['r', 'b', 'k', 'y', 'm', 'c', 'g', 'w'];

fieldsSC = fieldnames(SC);
for iSCRegion = 1:length(fieldsSC)
    figure;
    SC_Nuclei = SC.(fieldsSC{iSCRegion});
    clear cLine
    cLine = []; % Initialize cLine to ensure it is always defined
    for iNucleus = 1:numel(SC_Nuclei)
        idNucleus = find(strcmpi(st.name(:), SC_Nuclei{iNucleus}));
        index = st.sphinx_id(idNucleus);

        if ~isempty(index)

            cIdx = ~isnan(fluorescenceAvg(index, :));
            
            if ~isempty(find(cIdx))
                xVals = sliceSteps(cIdx);

                cData = fluorescenceAvg(index, cIdx);
                semData = fluorescenceSEM(index, cIdx);

                hold on;
                cLine(iNucleus) = errorshade(xVals, cData, semData, semData, plotColor(iNucleus), 0.2, 3);
            end
        end
    end
    niceFigure;
    
    % Check if cLine is not empty before calling legend
    hLine = findobj(gcf, 'Type', 'Line');
    legendIdx = find(cLine);
    legend(hLine, SC_Nuclei{legendIdx});
%     xlim([0 size(tv, 1)]);
    xlim([780 1020]);
    ylim([0 0.75]);
    set(gca, 'ylim', [0 0.75]);
    set(gca, 'ytick', 0:0.15:0.75);
            
    % Add labels and title
    xlabel('SC Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsSC{iSCRegion})));
end

%% Get fluorescence Traces for a given area
Str.CP = {"Caudoputamen"};
Str.Parts = {"Striatum", "Striatum dorsal region", "Striatum ventral region"};

plotColor = ['r', 'b', 'k', 'y', 'm', 'c', 'g', 'w'];

fieldsTn = fieldnames(Str);
for iTnRegion = 1:length(Str)
    figure;
    Tn_Nuclei = Str.(fieldsTn{iTnRegion});
    clear cLine
    for iNucleus = 1:numel(Tn_Nuclei)
        idNucleus = find(strcmpi(st.name(:), Tn_Nuclei{iNucleus}));
        index = st.sphinx_id(idNucleus);

        if ~isempty(index)

            cIdx = ~isnan(fluorescenceAvg(index, :));
            xVals = sliceSteps(cIdx);
          
            cData = fluorescenceAvg(index, cIdx);
           
            semData = fluorescenceSEM(index, cIdx);
           
         
            hold on;
            cLine(iNucleus) = errorshade(xVals, cData(:), semData(:), semData(:), plotColor(iNucleus), 0.2, 3);
            
            
%             pause
%             valuesSEM = fluorescenceSEM(index, 2:end);
%             valuesMax = fluorescenceMax(index, 2:end);
%             valuesMin = fluorescenceMin(index, 2:end);

%             num_values = numel(values_cell);
%             values = NaN(1, num_values); 
% 
%             for iValue = 1:num_values
% 
%                 if isnumeric(values_cell(iValue)) && ~isnan(values_cell(iValue))
% 
%                     values(iValue) = values_cell(iValue);
%                 end
%             end

%             plot(find(~isnan(values)), smooth(values(~isnan(values))));
%             legendNuclei = cell(1, iNucleus*2);
%             legendNuclei(1:2:end) = {Thalamic_Nuclei{1:iNucleus}};
%             for iLeg = 2:2:iNucleus*2
%                 legendNuclei(iLeg) = {"Error "+ Thalamic_Nuclei{iLeg/2}};
%             end
%             
%             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
%             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
%             hold on;

        end
    end
    niceFigure;
    legend(cLine, Tn_Nuclei);
%     xlim([0 size(tv, 1)]);
    xlim([340 820]);
    ylim([0 5]);
    set(gca, 'ylim', [0 4.5]);
    set(gca, 'ytick', 0:0.9:4.5);
            
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of RL somata into ',(fieldsTn{iTnRegion})));
end
