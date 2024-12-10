 %%
trace_folder = dir('E:\Histology\SOM exampels\KO_V1_SC\Original\*_CY5.tif');
dapi_folder = dir('E:\Histology\SOM exampels\KO_V1_SC\Original\*_DAPI.tif');


trace = imresize(imread(fullfile(trace_folder.folder,trace_folder.name)),1);
dapi = imresize(imread(fullfile(dapi_folder.folder,dapi_folder.name)),1);

mergeSize = size(trace);

merge = zeros(mergeSize(1),mergeSize(2),3,'uint8');

merge(:,:,3) = ((double(dapi) ./ 2^16 ).* (2^8 - 1))*10;
merge(:,:,1) = (double(trace) ./ 2^16) .* (2^8 - 1)*10;


% t = Tiff('MergeImage.tif','w'); 


imwrite(merge,'E:\Histology\SOM exampels\KO_V1_SC\MergeImage.tif','tif');