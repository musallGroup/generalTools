%% Load Atlas Data and Processed Images

% directory of processed image
Image_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
allImages = dir(fullfile(Image_folder,'*.tif'));
allTransform = dir(fullfile(Image_folder,'*.mat'));

% directory of AtlasData
Atlas_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
Atlas_file_name = 'AtlasData';
Save_name = 'FluorescenceMatrix_';
Save_name_cumulative = 'FluorescenceMatrixCumulative_';
Save_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';

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
        diffImg = Transformed_image(:,:,1); %subtract green channel from red to remove brightfield component
        %%if you want to seperate the green from red to keep the red :,:,1
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
Atlas_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
Atlas_file_name = 'AtlasData';
Atlas_FullPath_File = fullfile(Atlas_folder, Atlas_file_name);
AtlasFile = load(Atlas_FullPath_File);
Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\Results_2853';%% the fluoresncematrix tables and the fluorcumulative are getting saved together with the Atlas Data so it is throwing an error 

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

Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(Tn_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Thalamic Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsTn{iTnRegion})));
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
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsSC{iSCRegion})));
end

%% test Motor Cortex

Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(Motor_Nuclei{1:iNucleus});
%             xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Secondary Motor Cortex Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsMotor{iMotorRegion})));
end
%% %% test Somatosensory Cortex

Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
%             hold on;
            niceFigure;
            legend(Somatosensory_Nuclei{1:iNucleus});
%             xlim([0 65])
% %             ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Somatosensory Cortex barrel field area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsSomatosensory{iSomatosensoryRegion})));
end
%% Test Anterolateral visual area

Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(AntVisual_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anterolateral Visual area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsAntVisual{iAntVisualRegion})));
end
%% Test Anterior_Cingulate Cortex 


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
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

                if isnumeric(values_cell{iValue}) && ~isnan(values_cell{iValue})

                    values(iValue) = values_cell{iValue};
                end
            end

            plot(find(~isnan(values)), values(~isnan(values)));
            hold on;
            niceFigure;
            legend(AntCingulate_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anterior Cingulate Cortex Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsAntCingulate{iAntCingulateRegion})));
end
%% Test Retrosplenial area


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
Retrosplenial.dorsal = { '"Retrosplenial area dorsal part layer 1"', '"Retrosplenial area dorsal part layer 2/3"', '"Retrosplenial area dorsal part layer 5"',...
    '"Retrosplenial area dorsal part layer 6a"', '"Retrosplenial area dorsal part layer 6b"'};
Retrosplenial.ventral = { '"Retrosplenial area ventral part layer 1"', '"Retrosplenial area ventral part layer 2/3"', '"Retrosplenial area ventral part layer 5"', '"Retrosplenial area ventral part layer 6a"', '"Retrosplenial area ventral part layer 6b"'};
fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsRetrosplenial = fieldnames(Retrosplenial);
for iRetrosplenialRegion = 1:length(fieldsRetrosplenial)
    figure;
   Retrosplenial_Nuclei = Retrosplenial.(fieldsRetrosplenial{iRetrosplenialRegion});
    for iNucleus = 1:numel(Retrosplenial_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Retrosplenial_Nuclei{iNucleus}));

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
            legend(Retrosplenial_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Retrosplenial area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsRetrosplenial{iRetrosplenialRegion})));
end

%% Test Anteromedial visual area 


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
AnteromedialVisual.area = { '"Anteromedial visual area layer 1"', '"Anteromedial visual area layer 2/3"', '"Anteromedial visual area layer 4"',...
    '"Anteromedial visual area layer 5"', '"Anteromedial visual area layer 6a"', '"Anteromedial visual area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsAnteromedialVisual = fieldnames(AnteromedialVisual);
for iAnteromedialVisualRegion = 1:length(fieldsAnteromedialVisual)
    figure;
    AnteromedialVisual_Nuclei = AnteromedialVisual.(fieldsAnteromedialVisual{iAnteromedialVisualRegion});
    for iNucleus = 1:numel(AnteromedialVisual_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), AnteromedialVisual_Nuclei{iNucleus}));

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
            legend(AnteromedialVisual_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anteromedial Visual area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsAnteromedialVisual{iAnteromedialVisualRegion})));
end
%% Test Anterior visual area 


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
AnteriorVisual.area = { '"Anterior area layer 1"', '"Anterior area layer 2/3"', '"Anterior area layer 4"',...
    '"Anterior area layer 5"', '"Anterior area layer 6a"', '"Anterior area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsAnteriorVisual = fieldnames(AnteriorVisual);
for iAnteriorVisualRegion = 1:length(AnteriorVisual)
    figure;
    AnteriorVisual_Nuclei = AnteriorVisual.(fieldsAnteriorVisual{iAnteriorVisualRegion});
    for iNucleus = 1:numel(AnteriorVisual_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), AnteriorVisual_Nuclei{iNucleus}));

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
            legend(AnteriorVisual_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Anterior Visual area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsAnteriorVisual{iAnteriorVisualRegion})));
end
%% Test Rostrolateral area 


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
Rostrolateral.area = { '"Rostrolateral area layer 1"', '"Rostrolateral area layer 2/3"', '"Rostrolateral area layer 4"',...
    '"Rostrolateral area layer 5"', '"Rostrolateral area layer 6a"', '"Rostrolateral area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsRostrolateral = fieldnames(Rostrolateral);
for iRostrolateralRegion = 1:length(Rostrolateral)
    figure;
    Rostrolateral_Nuclei = Rostrolateral.(fieldsRostrolateral{iRostrolateralRegion});
    for iNucleus = 1:numel(Rostrolateral_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Rostrolateral_Nuclei{iNucleus}));

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
            legend(Rostrolateral_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Rostrolateral area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsRostrolateral{iRostrolateralRegion})));
end
%% %%Test Visual Cortex area 


Results_folder = 'C:\Users\abourachid\images _by_order\processed\transformations\FluoQuantification';
Results_file_name = 'FluorescenceMatrixCumulative_';
Results_folder_File = fullfile(Results_folder, Results_file_name);
CumulativeMatrix = load(Results_folder_File);

% Striatum = {'Caudoputamen'};
Visual.Cortex = { '"Primary visual area layer 1"', '"Primary visual area layer 2/3"', '"Primary visual area layer 4"',...
    '"Primary visual area layer 5"', '"Primary visual area layer 6a"', '"Primary visual area layer 6b"'};

fluorescenceMatrix = CumulativeMatrix.fluorescenceMatrix;
fieldsVisual = fieldnames(Visual);
for iVisualRegion = 1:length(Visual)
    figure;
    Visual_Nuclei = Visual.(fieldsVisual{iVisualRegion});
    for iNucleus = 1:numel(Visual_Nuclei)
        index = find(strcmpi(fluorescenceMatrix(:, 1), Visual_Nuclei{iNucleus}));

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
            legend(Visual_Nuclei{1:iNucleus});
            xlim([0 65])
            ylim([0 10])
        end
    end
    % Add labels and title
    xlabel('Visual Cortex area Length');
    ylabel('Mean Fluorescence');
    title(cat(2, 'AP distribution of V1 projetions into ',(fieldsVisual{iVisualRegion})));
end


%% Loop on all brains to average
stepSize = 10;
sliceSteps = 1: stepSize : size(av,1);

histologyPath = 'C:\Users\abourachid\images _by_order\';
fileNames = '*'; 
Atlas_folder = 'C:\Users\abourachid\images _by_order\processed\transformations';
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

% %% Get fluorescence Traces for a given area
% 
% % Striatum = {'Caudoputamen'};
% Tn.Thalamus = {"Thalamus"};
% Tn.ThalamicVentral = {"Ventral anterior-lateral complex of the thalamus", "Ventral medial nucleus of the thalamus", "Ventral posterolateral nucleus of the thalamus", "Ventral posteromedial nucleus of the thalamus"};
% Tn.ThalamicPosterior = {"Lateral posterior nucleus of the thalamus", "Posterior complex of the thalamus"};
% Tn.ThalamicCentral = { "Lateral dorsal nucleus of thalamus", "Intermediodorsal nucleus of the thalamus", "Mediodorsal nucleus of thalamus",...
%     "Nucleus of reuniens", "Rhomboid nucleus", "Central medial nucleus of the thalamus", "Paracentral nucleus","Central lateral nucleus of the thalamus"};
% Tn.ThalamicParaventricular = {"Paraventricular nucleus of the thalamus"};
% Tn.ThalamicInhibitory = {"Reticular nucleus of the thalamus"};
% plotColor = ['r', 'b', 'k', 'y', 'm', 'c', 'g', 'w'];
% 
% fieldsAnteromedialVisual = fieldnames(Tn);
% for iThalamicRegion = 1:length(fieldsAnteromedialVisual)
%     figure;
%     AnteromedialVisual_Nuclei = Tn.(fieldsAnteromedialVisual{iThalamicRegion});
%     clear cLine
%     for iNucleus = 1:numel(AnteromedialVisual_Nuclei)
%         idNucleus = find(strcmpi(st.name(:), AnteromedialVisual_Nuclei{iNucleus}));
%         index = st.sphinx_id(idNucleus);
% 
%         if ~isempty(index)
% 
%             cIdx = ~isnan(fluorescenceAvg(index, :));
%             xVals = sliceSteps(cIdx);
%             
%             cData = fluorescenceAvg(index, cIdx);
%             semData = fluorescenceSEM(index, cIdx);
%             
%             hold on;
%             cLine(iNucleus) = errorshade(xVals, cData, semData, semData, plotColor(iNucleus), 0.2, 3);
%             
%             
% %             pause
% %             valuesSEM = fluorescenceSEM(index, 2:end);
% %             valuesMax = fluorescenceMax(index, 2:end);
% %             valuesMin = fluorescenceMin(index, 2:end);
% 
% %             num_values = numel(values_cell);
% %             values = NaN(1, num_values); 
% % 
% %             for iValue = 1:num_values
% % 
% %                 if isnumeric(values_cell(iValue)) && ~isnan(values_cell(iValue))
% % 
% %                     values(iValue) = values_cell(iValue);
% %                 end
% %             end
% 
% %             plot(find(~isnan(values)), smooth(values(~isnan(values))));
% %             legendNuclei = cell(1, iNucleus*2);
% %             legendNuclei(1:2:end) = {Thalamic_Nuclei{1:iNucleus}};
% %             for iLeg = 2:2:iNucleus*2
% %                 legendNuclei(iLeg) = {"Error "+ Thalamic_Nuclei{iLeg/2}};
% %             end
% %             
% %             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
% %             cLine(iNucleus) = errorshade(find(~isnan(values)), values(~isnan(values)), valuesMax(~isnan(valuesMax)), valuesMin(~isnan(valuesMin)), plotColor(iNucleus), 0.2, 5);
% %             hold on;
% 
%         end
%     end
%     niceFigure;
%     legend(cLine, AnteromedialVisual_Nuclei);
%     xlim([0 size(tv, 1)])
%     ylim([0 10])
%             
%     % Add labels and title
%     xlabel('Thalamic Length');
%     ylabel('Mean Fluorescence');
%     title(cat(2, 'AP distribution of ALM projetions into ',(fieldsAnteromedialVisual{iThalamicRegion})));
% end

