function T = plotFolderSizesPie(parentDir)
% getFolderSizesSorted
% Returns and prints folder sizes (including subfolders), sorted descending
%
% INPUT:
%   parentDir - path to directory (e.g. 'D:\')
%
% OUTPUT:
%   T - table with folder names and sizes (GB), sorted descending

    if nargin < 1 || ~isfolder(parentDir)
        error('Provide a valid directory path.');
    end

    items = dir(parentDir);

    % Keep only folders (exclude . and ..)
    isDir = [items.isdir];
    folderNames = {items(isDir).name};
    folderNames = folderNames(~ismember(folderNames, {'.','..'}));

    n = numel(folderNames);
    sizes = zeros(n,1);

    for i = 1:n
        folderPath = fullfile(parentDir, folderNames{i});
        sizes(i) = getFolderSizeRecursive(folderPath);
    end

    % Convert to GB
    sizesGB = sizes / (1024^3);

    % Create table
    T = table(folderNames(:), sizesGB, ...
        'VariableNames', {'Folder', 'Size_GB'});

    % Sort descending
    T = sortrows(T, 'Size_GB', 'descend');

    % Display nicely
    fprintf('\nFolder sizes in: %s\n\n', parentDir);
    for i = 1:height(T)
        fprintf('%-40s %10.2f GB\n', T.Folder{i}, T.Size_GB(i));
    end
end


function totalSize = getFolderSizeRecursive(folderPath)
% Recursively sum all file sizes in a folder

    files = dir(folderPath);

    totalSize = 0;

    for i = 1:length(files)
        name = files(i).name;

        if strcmp(name,'.') || strcmp(name,'..')
            continue;
        end

        fullPath = fullfile(folderPath, name);

        if files(i).isdir
            totalSize = totalSize + getFolderSizeRecursive(fullPath);
        else
            totalSize = totalSize + files(i).bytes;
        end
    end
end