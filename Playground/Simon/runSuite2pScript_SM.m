% required paths
notebookPath = 'F:\runSuite2pFolders.ipynb';
envPath = 'C:\Users\musall\anaconda3\envs\suite2p\python.exe';

% run the code
pyenv('Version', envPath);
cmd = sprintf('"%s" "%s"', 'C:\Users\musall\anaconda3\envs\suite2p\python.exe', notebookPath);
[status, cmdout] = system(cmd, '-echo');
