function file_paths = abs_paths(root_path)

d = dir(root_path);

file_paths = cell(1, length(d));
cnt = 0;
for i = 1:length(d)
    if ~(strcmp(d(i).name, '.') || strcmp(d(i).name, '..'))
        file_paths{i} = fullfile(d(i).folder, d(i).name);
        cnt = cnt + 1;
    end
end
file_paths = file_paths(1:cnt);
