function files_only_in_A = compareFolders(A,B)
% This function compares the contents of two folders A and B and outputs
% a list of files that are present in folder A but not folder B.

% Get the list of files in folder A
files_A = dir(A);
files_A = files_A(3:end); % Remove the '.' and '..' directories

% Get the list of files in folder B
files_B = dir(B);
files_B = files_B(3:end); % Remove the '.' and '..' directories

% Compare the file names in folder A with folder B
files_only_in_A = setdiff({files_A.name},{files_B.name});

% Display the results
% disp('Files only in folder A:');
% disp(files_only_in_A');
end