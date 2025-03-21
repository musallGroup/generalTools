function status = runSuite2pScript_SM(notebookPath, envPath)

% % required paths
% notebookPath = 'F:\runSuite2pFolders.ipynb';
% envPath = 'C:\Users\scanimage\miniforge3\envs\suite2p\python.exe';

% run the code
cmd = sprintf('"%s" "%s"', envPath, notebookPath);
[status, cmdout] = system(cmd, '-echo');
