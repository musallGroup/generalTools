function make_dir(path)
if not(exist(path, 'dir'))
    try
        mkdir(path);
    catch
    end
end
