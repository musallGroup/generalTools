%% Load Atlas Data and Processed Images
minAreaSizeforPlot = 100; %number of pixels in a given area before its plotted on the histo image
colorChannel = 1; %this would be red, green, blue for 1,2,3

% directory of processed image
serverPath = '\\Fileserver\Allgemein\transfer\for Irene\data';
localSavePath = 'E:\Histology_AnterogradeALM';
serverFolder = 'ALM_SC_03_tifs\C5_TL_GFP\processed\transformations\'; %path to transofrmed images
Image_folder = fullfile(serverPath, serverFolder);
Save_folder = fullfile(localSavePath, serverFolder);


% directory of AtlasData
Atlas_folder = 'E:\Histology_Test\'; %path to saved AtlasData
Atlas_file_name = 'AtlasData';
Save_name = 'FluorescenceMatrix_';
Save_name_cumulative = 'FluorescenceMatrixCumulative_';
Save_name_fig = 'FluorescenceFigure_';
% Save_folder = '\\Fileserver\Allgemein\transfer\for Irene\data\ALM_SC_04_tifs\C5_TL_GFP\processed\transformations\'; %path to folder to save the analyzed data


%% only use files where both tif and transformed matlab data exist
allImages = dir(fullfile(Image_folder,'*.tif'));
allTransform = dir(fullfile(Image_folder,'*_processed_transform_data.mat'));

% Define a function to extract the numbers from file names using textscan
extractNumber = @(fileName) textscan(fileName, '%s%s%d', 1, 'Delimiter', '-');
imgNumbers = cellfun(@(c) c{3}, cellfun(extractNumber, {allImages(:).name}, 'UniformOutput', false));
matNumbers = cellfun(@(c) c{3}, cellfun(extractNumber, {allTransform(:).name}, 'UniformOutput', false));

imUseIdx = ismember(imgNumbers, matNumbers); %check for images that have no transform
matUseIdx = ismember(matNumbers, imgNumbers(imUseIdx)); %check for transforms that have no images

% only use correct files
allImages = allImages(imUseIdx);
allTransform = allTransform(matUseIdx);

%% load atlas data
full_path_atlas = fullfile(Atlas_folder, Atlas_file_name + ".mat");
AtlasData = load(full_path_atlas);
av = AtlasData.allData.av;
st = AtlasData.allData.st;
tv = AtlasData.allData.tv;
    
%% define steps for averaging slices to a certain range in the Allen atlas.
% stepSize = 10 would mean we combine all slices in a range of 10 slices in
% the Allen reference.
stepSize = 10;
sliceSteps = 1: stepSize : size(av,1);
avgSliceData = cell(1, length(sliceSteps));
avgSliceCnt = zeros(1, length(sliceSteps));

% loop over brains
h = figure('renderer', 'painters');
% Set the figure to A4 size
h.Position = [1          41        1920         963];
set(h, 'PaperUnits', 'centimeters');
set(h, 'PaperSize', [29.7, 21]); % A4 size in centimeters
set(h, 'PaperPositionMode', 'manual');
set(h, 'PaperPosition', [0, 0, 29.7, 21]);
for iSlice = 1:length(allImages)

    %Image_file_name = 'Composite9_GFP-tdTomato_processed_transform_data';   
    Transform_file_name = allTransform(iSlice).name;
    full_path_file = fullfile(Image_folder, Transform_file_name);
    transformData = load(full_path_file);
    current_slice = transformData.save_transform.allen_location{1};

    % directory of Transformed Image
    %Transformed_image = imread('Y:\Histology_Musall\Histology_Irene\Moritz\M133_Tiff\processed3\transformations\Composite13_GFP-tdTomato_processed_transformed.tif');
    Transformed_image = imread(fullfile(Image_folder, allImages(iSlice).name));
    subplot(1,3,3); cla;
    subplot(1,3,2); cla;
    subplot(1,3,1); cla;
    imshow(Transformed_image); 
    title('Confirm flip here'); drawnow;
     
    % stay in a loop until no slice flipping is required anymore
    cResp = [];
    while strcmpi(cResp, 'y') || isempty(cResp)
        cResp = input('Hit Y to flip image or any other button to continue\n', 's');
        % flip the image if requested
        if strcmpi(cResp, 'y')
            Transformed_image = fliplr(Transformed_image);
            cla;
            imshow(Transformed_image); title('Confirm flip here'); axis image;
        end
    end
    title(['Fluorescence; Current slice: ' num2str(current_slice)]);

    subplot(1,3,2); cla;
    imshow(Transformed_image); axis image; hold on;
    title(['Fluorescence+Outlines; Current slice: ' num2str(current_slice)]); axis image;
    
    %% Find Histology Plane into the AtlasData and Calculate mean fluorescence within each Brain Region (ROI)
    subplot(1,3,3); cla;
    imagesc(squeeze(av(current_slice,:,:)));
    title(['Allen slice ' num2str(current_slice)]); axis image;
    
    % keep average of transformed image as part of the corresponding allen average slice
    allenSliceRange = find(sliceSteps <= current_slice, 1, 'last'); %find in which bin the slice is located
    avgSliceCnt(allenSliceRange) = avgSliceCnt(allenSliceRange) + 1; %increase counter for current bin
    avgSliceData{allenSliceRange} = runMean(avgSliceData{allenSliceRange}, Transformed_image, avgSliceCnt(allenSliceRange));
    fprintf('Current slice bin: %i, Total slice count in this bin: %i\n', allenSliceRange, avgSliceCnt(allenSliceRange));
    
    %% check regions
    RegionsID = (unique(av(current_slice,:,:)));
    meanFluorescence = zeros(length(RegionsID), size(Transformed_image,3));
    regionId = zeros(length(RegionsID),1);
    regionName = strings(length(RegionsID),1);
    regionAcr = strings(length(RegionsID),1);

    concatenatedTable = [];
    for cID = 1: length(RegionsID)

        locID = squeeze(av(current_slice,:,:)) == RegionsID(cID); %get mask for current area
        cData = arrayShrink(Transformed_image, ~locID, 'merge'); %this function extracts the pixels from all channels in the current area
        meanFluorescence(cID,:) = mean(cData, 1);
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
    % save data table
    fluoTable = table(regionId,regionAcr,regionName,meanFluorescence);
    save(fullfile(Save_folder, Save_name + string(current_slice) + ".mat"), "fluoTable");

    % save figure as jpg and pdf
    set(h, 'Color', 'w');
    set(h, 'InvertHardcopy', 'off');
    saveas(h, fullfile(Save_folder, Save_name_fig + string(current_slice) + ".jpg"));
    saveas(h, fullfile(Save_folder, Save_name_fig + string(current_slice) + ".pdf"));
    fprintf('Current slice %i/%i\n', iSlice, length(allImages));
    pause;
end

%save avgSliceData to file
save(fullfile(Save_folder, 'avgSliceData.mat'), 'avgSliceData', 'avgSliceCnt', 'sliceSteps');


%% Create a table for concatenated fluorescence values
Atlas_folder = 'E:\Histology_Test';
Atlas_file_name = 'AtlasData';
Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
AtlasFile = load(Atlas_FullPath_File);
Results_folder = '\\Fileserver\Allgemein\transfer\for Irene\data\ALM_SC_04_tifs\C5_TL_GFP\processed\transformations\test\New folder';

av = AtlasFile.allData.av;
st = AtlasFile.allData.st;
tv = AtlasFile.allData.tv;

allFiles = dir(fullfile(Results_folder,'*.mat'));
numFiles = size(allFiles,1);

AllRegionID = unique(AtlasFile.allData.st.sphinx_id);

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
        iRegion = allRegions(iReg);
        regionRow = find(ismember(string(fluorescenceMatrix),iRegion));
        fluorescenceMatrix(regionRow,iFile+1) = {fluoTable.meanFluorescence(find(strcmpi(fluoTable.regionName,iRegion)))};
    end
end

Results_folder = '\\Fileserver\Allgemein\transfer\for Irene\data\ALM_SC_04_tifs\C5_TL_GFP\processed\transformations\test\New folder';
save(fullfile(Results_folder, [Save_name_cumulative '.mat']), 'fluorescenceMatrix', 'idx');



%% Get fluorescence Traces for a given area

% Need to change this in order to apply it to several datasets

Results_folder = 'E:\Histology_Test\ALM_SC_05';
Results_file_name = 'FluorescenceMatrixCumulative_';
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
for iThalamicRegion = 1:length(fieldsTn)
    figure;
    Thalamic_Nuclei = Tn.(fieldsTn{iThalamicRegion});
    for iNucleus = 1:numel(Thalamic_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Thalamic_Nuclei{iNucleus}));

        if ~isempty(index)

            values_cell = fluorescenceMatrix(index, 2:end);

            num_values = numel(values_cell);
            values = NaN(1, num_values); 

            for iValue = 1:num_values

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(Thalamic_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsTn{iThalamicRegion})));
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(SC_Nuclei{1:iNucleus});
%             xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('SC Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsTn{iSCRegion})));
end

%% Loop on all brains to average


histologyPath = 'E:\Histology_Test\';
fileNames = 'ALM_SC_*'; 
Atlas_folder = 'E:\Histology_Test';
Atlas_file_name = 'AtlasData';
Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
AtlasFile = load(Atlas_FullPath_File);

av = AtlasFile.allData.av;
st = AtlasFile.allData.st;
tv = AtlasFile.allData.tv;


AllRegionID = unique(AtlasFile.allData.st.sphinx_id);

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
%     It shouldn't be necessary to check that the names aren't '.' or '..'
%     because ze qre selecting only the files with ALM_SC in the name
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
                fluoVal = cat(1,fluoVal,fluorescenceMatrixes.(brainID){iReg,find(useIdx)+1});
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

%% Get fluorescence Traces for the thalamic area

% Striatum = {'Caudoputamen'};
Tn.Thalamus = {"Thalamus"};
Tn.ThalamicVentral = {"Ventral anterior-lateral complex of the thalamus", "Ventral medial nucleus of the thalamus", "Ventral posterolateral nucleus of the thalamus", "Ventral posteromedial nucleus of the thalamus"};
Tn.ThalamicPosterior = {"Lateral posterior nucleus of the thalamus", "Posterior complex of the thalamus"};
Tn.ThalamicCentral = { "Lateral dorsal nucleus of thalamus", "Intermediodorsal nucleus of the thalamus", "Mediodorsal nucleus of thalamus",...
    "Nucleus of reuniens", "Rhomboid nucleus", "Central medial nucleus of the thalamus", "Paracentral nucleus","Central lateral nucleus of the thalamus"};
Tn.ThalamicParaventricular = {"Paraventricular nucleus of the thalamus"};
Tn.ThalamicInhibitory = {"Reticular nucleus of the thalamus"};
plotColor = ['r', 'b', 'k', 'y', 'm', 'c', 'g', 'w'];

fieldsTn = fieldnames(Tn);
for iThalamicRegion = 1:length(fieldsTn)
    figure;
    Thalamic_Nuclei = Tn.(fieldsTn{iThalamicRegion});
    clear cLine
    for iNucleus = 1:numel(Thalamic_Nuclei)
        idNucleus = find(strcmpi(st.name(:), Thalamic_Nuclei{iNucleus}));
        index = st.sphinx_id(idNucleus);

        if ~isempty(index)

            cIdx = ~isnan(fluorescenceAvg(index, :));
            xVals = sliceSteps(cIdx);
            
            cData = fluorescenceAvg(index, cIdx);
            semData = fluorescenceSEM(index, cIdx);
            
            hold on;
            cLine(iNucleus) = errorshade(xVals, cData, semData, semData, plotColor(iNucleus), 0.2, 3);
            
            
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
    legend(cLine, Thalamic_Nuclei);
    xlim([0 size(tv, 1)])
    ylim([0 5])
            
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsTn{iThalamicRegion})));
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
    xlim([0 size(tv, 1)])
    ylim([0 5])
            
    % Add labels and title
    xlabel('SC Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsSC{iSCRegion})));
end

