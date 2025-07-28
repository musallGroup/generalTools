function dir_animal = find_dir(animal, session, base_dirs)

if exist([base_dirs{1} animal '_' , session], 'dir')
    dir_animal = [base_dirs{1} animal '_' session, ...
        filesep, animal '_' session '_g0'];
elseif exist([base_dirs{2} animal '_' , session], 'dir')
    dir_animal = [base_dirs{2} animal '_' session, ...
        filesep, animal '_' session '_g0'];
else
    disp(['no folder found for animal ' animal ...
        ' session ' session])
    dir_animal = [];
end
end