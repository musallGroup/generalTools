function make_dir(path)
if ~exist(path, 'dir')
    try
        mkdir(path);
    catch
    end
end
