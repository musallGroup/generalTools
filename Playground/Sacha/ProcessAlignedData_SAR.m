%% Load Atlas Data and Processed Images

% directory of processed image
Image_folder = '\\Naskampa\lts\Sacha\Histology_Julich\images_by_order\processed\transformations';
allImages = dir(fullfile(Image_folder,'*.tif'));
allTransform = dir(fullfile(Image_folder,'*.mat'));

% directory of AtlasData
Atlas_folder = '\\Naskampa\lts\Sacha\Histology_Julich\images_by_order\processed\transformations';
Atlas_file_name = 'AtlasData';
Save_name = 'FluorescenceMatrix_';
Save_name_cumulative = 'FluorescenceMatrixCumulative_';
Save_folder = '\\Naskampa\lts\Sacha\Histology_Julich\images _by_order\processed\transformations\FluoQuantification';

for iSlice = 1:length(allImages)

    %Image_file_name = 'Composite9_GFP-tdTomato_processed_transform_data';
    Image_file_name = allTransform(iSlice).name;
    full_path_file = fullfile(Image_folder, Image_file_name);
    ImageData = load(full_path_file);

    current_slice = ImageData.save_transform.allen_location{1};

    %full_path_atlas = fullfile(Atlas_folder, Atlas_file_name + string(current_slice) + ".mat");
    full_path_atlas = fullfile(Atlas_folder, Atlas_file_name + ".mat");
    AtlasData = load(full_path_atlas);

    % directory of Transformed Image
    %Transformed_image = imread('Y:\Histology_Musall\Histology_Irene\Moritz\M133_Tiff\processed3\transformations\Composite13_GFP-tdTomato_processed_transformed.tif');
    Transformed_image = imread(fullfile(Image_folder, allImages(iSlice).name));
    figure; imshow(Transformed_image);

    %% Find Histology Plane into the AtlasData and Calculate mean fluorescence within each Brain Region (ROI)

    av = AtlasData.allData.av;
    st = AtlasData.allData.st;
    tv = AtlasData.allData.tv;

    figure;
    imagesc(squeeze(av(current_slice,:,:)));

    RegionsID = (unique(av(current_slice,:,:)));

    meanFluorescence = zeros(length(RegionsID),1);
    regionId = zeros(length(RegionsID),1);

    regionName = strings(length(RegionsID),1);
    regionAcr = strings(length(RegionsID),1);

    concatenatedTable = [];
    
    for cID = 1: length(RegionsID)

        locID = squeeze(av(current_slice,:,:)) == RegionsID(cID);
        diffImg = Transformed_image(:,:,2); %subtract green channel from red to remove brightfield component
        %%if you want to seperate th egreen from red to keep th ered :,:,1
        meanFluorescence(cID) = mean(diffImg(locID), "all");
        regionName(cID) = st.name{RegionsID(cID)};
        regionAcr(cID) = st.acronym{RegionsID(cID)};
        regionId(cID) = RegionsID(cID);

    end
    fluoTable = table(regionId,regionAcr,regionName,meanFluorescence);
    save(fullfile(Save_folder, Save_name + string(current_slice) + ".mat"), "fluoTable");
end

% %% Extract SliceID
% Results_folder = 'E:\Histology_Test\ALM_SC_04';
% file_list = dir(fullfile(Results_folder, 'FluorescenceMatrix_*'));
% num_files = length(file_list);
% sliceID = zeros(num_files, 1); % Preallocate sliceID as an array
% 
% for i = 1:num_files
%     file_name = file_list(i).name;
%     match = regexp(file_name, '(\d+)', 'match');
%     
%     if ~isempty(match)
%         number = str2double(match{end}); 
%     else
%         number = NaN; %
%     end
%     
%     sliceID(i) = number; %
%    
% end
% 
% sliceID =  sort(sliceID);
%% Create a table for concatenated fluorescence values
Atlas_folder = '\\Naskampa\lts\Sacha\Histology_Julich\images_by_order\processed\transformations';
Atlas_file_name = 'AtlasData';
Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
AtlasFile = load(Atlas_FullPath_File);
Results_folder = '\\Naskampa\lts\Sacha\Histology_Julich\test\TestResults';%% the fluoresncematrix tables and the fluorcumulative are getting saved together with the Atlas Data so it is throwing an error 

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

save(fullfile(Results_folder, [Save_name_cumulative '.mat']), 'fluorescenceMatrix', 'idx');

%%
% %% Extract SliceID
% Results_folder = 'E:\Histology_Test\ALM_SC_04';
% file_list = dir(fullfile(Results_folder, 'FluorescenceMatrix_*'));
% num_files = length(file_list);
% sliceID = zeros(num_files, 1); % Preallocate sliceID as an array
% 
% for i = 1:num_files
%     file_name = file_list(i).name;
%     match = regexp(file_name, '(\d+)', 'match');
%     
%     if ~isempty(match)
%         number = str2double(match{end}); 
%     else
%         number = NaN; %
%     end
%     
%     sliceID(i) = number; %
% end
% 
% sorted_indices = sort(sliceID);


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

%% test Motor Cortex

Results_folder = '\\Naskampa\lts\Sacha\Histology_Julich\test\TestResults';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);
Cortex.Motor = {'"Secondary motor area layer 1"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsCortex = fieldnames(Cortex);
for iSCRegion = 1:length(fieldsCortex)
    figure;
    Cortex_Nuclei = Cortex.(fieldsCortex{iSCRegion});
    for iNucleus = 1:numel(Cortex_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Cortex_Nuclei{iNucleus}));

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
            legend(Cortex_Nuclei{1:iNucleus});
%             xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('SC Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsCortex{iSCRegion})));
end

%% Loop on all brains to average
stepSize = 10;
sliceSteps = 1: stepSize : size(av,1);

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

%% Get fluorescence Traces for a given area

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
    ylim([0 10])
            
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of ALM projetions into ',(fieldsTn{iThalamicRegion})));
end

