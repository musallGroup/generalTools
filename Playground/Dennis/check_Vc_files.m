function check_Vc_files(basePath, subjectIDs, outputFile)

% Collect results only for missing Vc.mat files
results = {};

row = 1;

for iSub = 1:length(subjectIDs)
    
    subjectID = subjectIDs(iSub);

    subjectPath = fullfile(basePath, num2str(subjectID), ...
        'UncertainUrchin', 'Session Data');

    if ~isfolder(subjectPath)
        fprintf('⚠️ Subject folder not found: %s\n', subjectPath);
        continue;
    end

    sessions = dir(subjectPath);
    sessions = sessions([sessions.isdir]);
    sessions = sessions(~ismember({sessions.name}, {'.', '..'}));

    fprintf('\n🔍 Checking Subject %d...\n', subjectID);

    for iSess = 1:length(sessions)

        sessionName = sessions(iSess).name;
        sessionPath = fullfile(subjectPath, sessionName);

        vcFile = fullfile(sessionPath, 'Vc.mat');

        existsFlag = isfile(vcFile);

        % ONLY store and print missing files
        if ~existsFlag

            results{row,1} = subjectID;
            results{row,2} = sessionName;
            results{row,3} = sessionPath;

            fprintf('❌ Missing: %s\n', sessionPath);

            row = row + 1;
        end
    end
end

% Convert to table
if ~isempty(results)

    T = cell2table(results, ...
        'VariableNames', {'SubjectID','Session','SessionPath'});

    % Write CSV
    writetable(T, outputFile);

    fprintf('\n✔️ Missing-session list saved to: %s\n', outputFile);

else
    fprintf('\n✅ No missing Vc.mat files found.\n');
end

end