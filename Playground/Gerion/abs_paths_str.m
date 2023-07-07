function file_paths = abs_paths_str(root_path)
% This code is almost identical to the "abs_paths.m" with the addition to
% convert the cell('char') to a string-array in the end.
% When I wrote the original function I didn't get that Matlab treats 
% char-arrays different from strings. Since I've always been working with
% character-arrays back then, having a cell-array was the only way I could
% make this work. In the future I would like to only ever use string-arrays
% for loop and such, but since I have a lot of codes that expect these
% cell('char') now I cant just change this, so this is an alternative
% function for now. 

d = dir(root_path);

file_paths = cell(1, length(d));
cnt = 0;
for i = 1:length(d)
    if ~(strcmp(d(i).name, '.') || strcmp(d(i).name, '..'))
        file_paths{cnt+1} = fullfile(d(i).folder, d(i).name);
        cnt = cnt + 1;
    end
end
file_paths = file_paths(1:cnt);

% This is ugly but it works for now while I convert my old codes to a str-version
file_paths = cellfun(@(x) string(x), file_paths);
