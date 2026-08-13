function check_Vc_files(localBasePath, serverBasePath, backupBasePath, outputFile)

% Cross-check processed data (Vc.mat) on the server against the full
% session list on the local experiment PC, before raw data on the
% server is moved to tape. The local PC is treated as ground truth for
% "which sessions exist" (it always gets a session folder, even though
% it doesn't keep the large files); the server is checked for a
% matching subject/session folder and a Vc.mat inside it. backupBasePath
% (e.g. a local backup drive mirroring the server layout) is checked as
% a secondary source when Vc.mat/a session is missing on the server, to
% tell "lost/never processed" apart from "just not synced yet". Note that
% a separate cleanup script prunes sessions from backupBasePath once
% they're confirmed fully transferred to the server, so a session's
% absence from the backup does not by itself mean it was never backed up.
% As a
% third source, the tape-transfer staging logs (transferLog_*.log files
% written by tapeTransfer.py) are scanned for the session's path, to
% catch the case where raw data was already staged/moved to tape before
% it was ever processed into Vc.mat.
%
% Each missing/incomplete session is assigned a Severity
% (OK/Info/Warning/Critical) describing how urgent it is, and the
% output is written as an .xlsx file with rows colored by severity
% (requires Excel to be installed, via COM automation).

taskNames = {'UncertainUrchin', 'PuffyPenguin', 'PhasemapPony'};
excludeSubjects = {'FakeSubject', 'snapshots'};
minDatSizeBytes = 50 * 1024^2; % raw .dat below this looks truncated/corrupt
numHabituationSessions = 5; % first N sessions per subject/task are habituation, no imaging expected
tapeTransferDirs = {'Y:\TAPE_TRANSFER\BpodBehavior', 'X:\TAPE_TRANSFER\BpodBehavior'};

if ~isfolder(localBasePath)
    error('check_Vc_files:missingLocalPath', ...
        'Local base path not found (check the drive is mounted): %s', localBasePath);
end

if ~isfolder(serverBasePath)
    error('check_Vc_files:missingServerPath', ...
        'Server base path not found (check the drive is mounted): %s', serverBasePath);
end

if ~isfolder(backupBasePath)
    error('check_Vc_files:missingBackupPath', ...
        'Backup base path not found (check the drive is mounted): %s', backupBasePath);
end

tapeLogPaths = scanTapeTransferLogs(tapeTransferDirs);

subjects = dir(localBasePath);
subjects = subjects([subjects.isdir]);
subjects = subjects(~ismember({subjects.name}, {'.', '..'}));
subjects = subjects(~ismember(lower({subjects.name}), lower(excludeSubjects)));

results = {};
row = 1;

for iSub = 1:length(subjects)

    subjectID = subjects(iSub).name;

    fprintf('\n🔍 Checking Subject %s...\n', subjectID);

    serverSubjectPath = fullfile(serverBasePath, subjectID);
    subjectMissingOnServer = ~isfolder(serverSubjectPath);

    if subjectMissingOnServer
        fprintf('❌ Subject missing on server: %s\n', serverSubjectPath);
    end

    for iTask = 1:length(taskNames)

        taskName = taskNames{iTask};

        localSessionPath = fullfile(localBasePath, subjectID, taskName, 'Session Data');

        if ~isfolder(localSessionPath)
            continue;
        end

        sessions = dir(localSessionPath);
        sessions = sessions([sessions.isdir]);
        sessions = sessions(~ismember({sessions.name}, {'.', '..'}));
        [~, sortIdx] = sort({sessions.name}); % chronological: session names are YYYYMMDD_HHMMSS
        sessions = sessions(sortIdx);

        for iSess = 1:length(sessions)

            sessionName = sessions(iSess).name;
            localSessionFolder = fullfile(localSessionPath, sessionName);
            serverSessionFolder = fullfile(serverBasePath, subjectID, taskName, 'Session Data', sessionName);
            backupSessionFolder = fullfile(backupBasePath, subjectID, taskName, 'Session Data', sessionName);
            isHabituationSession = iSess <= numHabituationSessions;

            if subjectMissingOnServer
                status = 'SubjectMissingOnServer';
            elseif ~isfolder(serverSessionFolder)
                status = 'SessionMissingOnServer';
            elseif ~isfile(fullfile(serverSessionFolder, 'Vc.mat'))
                status = 'VcMissing';
            else
                status = '';
            end

            if ~isempty(status)

                [reason, severity] = getMissingReason(status, localSessionFolder, serverSessionFolder, ...
                    backupSessionFolder, minDatSizeBytes, isHabituationSession, tapeLogPaths, ...
                    subjectID, taskName, sessionName);

                results{row,1} = subjectID;
                results{row,2} = taskName;
                results{row,3} = sessionName;
                results{row,4} = localSessionFolder;
                results{row,5} = serverSessionFolder;
                results{row,6} = status;
                results{row,7} = severity;
                results{row,8} = reason;

                fprintf('❌ [%s] %s [%s]: %s (%s)\n', severity, status, taskName, serverSessionFolder, reason);

                row = row + 1;
            end
        end
    end
end

% Convert to table
if ~isempty(results)

    T = cell2table(results, ...
        'VariableNames', {'SubjectID','Task','Session','LocalSessionPath','ServerSessionPath','Status','Severity','Reason'});

    % Force .xlsx so severity rows can be color-filled
    [outDir, outName] = fileparts(outputFile);
    if isempty(outDir)
        outDir = pwd;
    end
    xlsxOutputFile = fullfile(outDir, [outName '.xlsx']);
    if ~strcmpi(xlsxOutputFile, outputFile)
        fprintf('ℹ️ Writing Excel output (with severity coloring) to: %s\n', xlsxOutputFile);
    end
    outputFile = xlsxOutputFile;

    writetable(T, outputFile);

    try
        colorizeSeverityRows(outputFile, T.Severity, width(T));
    catch ME
        warning('check_Vc_files:colorizeFailed', ...
            'Report saved but severity coloring failed (is Excel installed?): %s', ME.message);
    end

    fprintf('\n✔️ Missing-session list saved to: %s\n', outputFile);

else
    fprintf('\n✅ No missing Vc.mat files found.\n');
end

end

function [reason, severity] = getMissingReason(status, localSessionFolder, serverSessionFolder, ...
    backupSessionFolder, minDatSizeBytes, isHabituationSession, tapeLogPaths, subjectID, taskName, sessionName)

switch status
    case 'SubjectMissingOnServer'
        reason = 'Entire subject folder missing on server - check server connectivity/mount and subject folder name spelling';
        severity = 'Critical';

    case 'SessionMissingOnServer'
        localDat = dir(fullfile(localSessionFolder, '*_1photon_*.dat'));
        backupHasVc = isfile(fullfile(backupSessionFolder, 'Vc.mat'));
        backupHasRaw = ~isempty(dir(fullfile(backupSessionFolder, '*_1photon_*.dat'))) ...
            || ~isempty(dir(fullfile(backupSessionFolder, '*_1photon_*.camlog')));
        foundOnTape = foundInTapeLog(tapeLogPaths, subjectID, taskName, sessionName);

        if ~isempty(localDat)
            reason = 'Session missing on server but raw .dat still found locally - not yet synced/transferred';
            severity = 'Info';
        elseif backupHasVc || backupHasRaw
            if backupHasVc
                reason = 'Session missing on server but Vc.mat found in local backup - check sync/transfer';
            else
                reason = 'Session missing on server but raw data found in local backup - check sync/transfer';
            end
            severity = 'Warning';
        elseif foundOnTape
            reason = 'Session missing on server and not in local backup, but raw data found in tape-transfer log - likely staged/moved to tape, check retrieval';
            severity = 'Warning';
        else
            reason = 'Session missing on server and no raw imaging data found locally, in backup, or in tape-transfer log - likely lost';
            severity = 'Critical';
        end

    case 'VcMissing'
        if isfile(fullfile(backupSessionFolder, 'Vc.mat'))
            reason = 'Vc.mat found in local backup but missing on server - needs to be copied to server';
            severity = 'Info';
            return;
        end

        if isHabituationSession
            reason = 'habituation';
            severity = 'OK';
            return;
        end

        backupHasRaw = ~isempty(dir(fullfile(backupSessionFolder, '*_1photon_*.dat'))) ...
            || ~isempty(dir(fullfile(backupSessionFolder, '*_1photon_*.camlog')));
        foundOnTape = foundInTapeLog(tapeLogPaths, subjectID, taskName, sessionName);

        serverFiles = dir(serverSessionFolder);
        serverFiles = serverFiles(~ismember({serverFiles.name}, {'.', '..'}));

        if isempty(serverFiles)
            if backupHasRaw
                reason = 'Empty session folder on server, but raw data found in local backup - needs to be copied to server and processed';
                severity = 'Warning';
            elseif foundOnTape
                reason = 'Empty session folder on server, but raw data found in tape-transfer log - likely staged/moved to tape before processing';
                severity = 'Warning';
            else
                reason = 'Empty session folder on server (no raw data at all) - check if session was restarted under a different folder';
                severity = 'Critical';
            end
            return;
        end

        camlogFiles = dir(fullfile(serverSessionFolder, '*_1photon_*.camlog'));
        datFiles = dir(fullfile(serverSessionFolder, '*_1photon_*.dat'));
        backupHasDat = ~isempty(dir(fullfile(backupSessionFolder, '*_1photon_*.dat')));

        if isempty(camlogFiles) && isempty(datFiles)
            reason = 'No imaging files found for this session (likely no imaging performed, e.g. habituation/training-only)';
            severity = 'OK';
        elseif isempty(datFiles)
            if backupHasDat
                reason = 'Imaging camlog present but raw .dat file missing on server - found in local backup, check transfer';
                severity = 'Warning';
            elseif foundOnTape
                reason = 'Imaging camlog present but raw .dat file missing on server - found in tape-transfer log, check retrieval';
                severity = 'Warning';
            else
                reason = [describeCamlogFrames(camlogFiles) ...
                    ', not found in local backup or tape-transfer log either'];
                severity = 'Critical';
            end
        elseif all([datFiles.bytes] < minDatSizeBytes)
            if backupHasDat
                reason = 'Raw .dat file present but unusually small (possibly truncated/corrupt) - an intact copy was found in local backup, check transfer';
                severity = 'Warning';
            elseif foundOnTape
                reason = 'Raw .dat file present but unusually small (possibly truncated/corrupt) - an intact copy was found in tape-transfer log, check retrieval';
                severity = 'Warning';
            else
                reason = 'Raw .dat file present but unusually small - possibly truncated/corrupt acquisition, no intact copy found in local backup or tape-transfer log';
                severity = 'Critical';
            end
        else
            reason = 'Raw imaging data present on server, not yet processed to Vc.mat';
            severity = 'Info';
        end

    otherwise
        reason = '';
        severity = '';
end

end

function reasonPrefix = describeCamlogFrames(camlogFiles)

% Summarizes what the 1photon camlog(s) actually recorded, to tell a
% genuinely aborted acquisition (no/few frames) apart from a recording
% that completed and whose .dat file is now missing (real data lost).
% Takes the camlog with the highest frame count as representative when
% a session was restarted and has more than one 1photon camlog.

best = struct('frameCount', -1, 'completed', false, 'targetDatFile', '');

for iLog = 1:numel(camlogFiles)
    info = parseCamlogFrames(fullfile(camlogFiles(iLog).folder, camlogFiles(iLog).name));
    if info.frameCount > best.frameCount
        best = info;
    end
end

if numel(camlogFiles) > 1
    attemptNote = sprintf(' (%d recording attempts logged)', numel(camlogFiles));
else
    attemptNote = '';
end

if best.frameCount <= 0
    reasonPrefix = ['Imaging camlog present but raw .dat file missing; camlog shows no frames ' ...
        'were recorded - likely aborted before acquisition started' attemptNote];
elseif ~best.completed
    reasonPrefix = sprintf(['Imaging camlog present but raw .dat file missing; camlog has no clean ' ...
        'completion record (~%d frames logged before it stopped, recording software may have crashed)%s'], ...
        best.frameCount, attemptNote);
else
    reasonPrefix = sprintf(['Imaging camlog present but raw .dat file missing; camlog confirms %d frames ' ...
        'were successfully written to %s - the file is now missing (this was not an aborted acquisition, ' ...
        'real data was recorded and then lost)%s'], best.frameCount, best.targetDatFile, attemptNote);
end

end

function info = parseCamlogFrames(camlogFilePath)

% Parses a single labcams *_1photon_*.camlog file. A clean recording
% ends with a line like "Wrote 88056 frames on 1photon (1 files)."; if
% that's absent (e.g. the recording software crashed), the frame count
% is estimated by counting "frame_id,timestamp" data lines instead.

info = struct('frameCount', 0, 'completed', false, 'targetDatFile', '');

logText = fileread(camlogFilePath);

wroteTok = regexp(logText, 'Wrote (\d+) frames', 'tokens', 'once');
if ~isempty(wroteTok)
    info.frameCount = str2double(wroteTok{1});
    info.completed = true;
else
    dataLineMatches = regexp(logText, '^\d+,', 'lineanchors');
    info.frameCount = numel(dataLineMatches);
    info.completed = false;
end

targetTok = regexp(logText, '\]\s*-\s*(.+\.dat)\s*$', 'tokens', 'once', 'lineanchors');
if ~isempty(targetTok)
    [~, fname, ext] = fileparts(strtrim(targetTok{1}));
    info.targetDatFile = [fname ext];
end

end

function tapeLogPaths = scanTapeTransferLogs(tapeTransferDirs)

% Scans transferLog_*.log files (written by tapeTransfer.py) for the
% source path of every COPY/MOVE/DEL-SRC entry, so missing sessions can
% be checked against what has actually passed through tape staging.

tapeLogPaths = {};

for iDir = 1:length(tapeTransferDirs)

    tapeDir = tapeTransferDirs{iDir};

    if ~isfolder(tapeDir)
        warning('check_Vc_files:missingTapeTransferPath', ...
            'Tape-transfer log path not found (skipping): %s', tapeDir);
        continue;
    end

    logFiles = dir(fullfile(tapeDir, 'transferLog_*.log'));

    for iLog = 1:length(logFiles)
        logText = fileread(fullfile(logFiles(iLog).folder, logFiles(iLog).name));
        tokens = regexp(logText, '^\[(?:COPY|MOVE|DEL-SRC)\]\s+(.+?)(?=\s->\s|\s\(dst)', ...
            'tokens', 'lineanchors');
        tokens = [tokens{:}]; % flatten 1x1 cells into a plain cell array of char
        tapeLogPaths = [tapeLogPaths, tokens]; %#ok<AGROW>
    end
end

end

function tf = foundInTapeLog(tapeLogPaths, subjectID, taskName, sessionName)

if isempty(tapeLogPaths)
    tf = false;
    return;
end

sessionRelPath = fullfile(subjectID, taskName, 'Session Data', sessionName);
tf = any(contains(tapeLogPaths, sessionRelPath, 'IgnoreCase', true));

end

function colorizeSeverityRows(outputFile, severities, numCols)

severityColors = struct( ...
    'OK',       rgbToOleColor(198, 239, 206), ...
    'Info',     rgbToOleColor(255, 235, 156), ...
    'Warning',  rgbToOleColor(255, 204, 153), ...
    'Critical', rgbToOleColor(255, 199, 206));

excelApp = actxserver('Excel.Application');
cleanupExcel = onCleanup(@() closeExcelApp(excelApp));
excelApp.Visible = false;
excelApp.DisplayAlerts = false;

workbook = excelApp.Workbooks.Open(outputFile);
sheet = workbook.Sheets.Item(1);
lastColLetter = colIndexToLetter(numCols);

for iRow = 1:numel(severities)
    excelRow = iRow + 1; % offset header row
    color = severityColors.(severities{iRow});
    rangeAddress = sprintf('A%d:%s%d', excelRow, lastColLetter, excelRow);
    range = sheet.Range(rangeAddress);
    range.Interior.Color = color;
end

workbook.Save();
workbook.Close(false);

end

function letters = colIndexToLetter(colIdx)

% Converts a 1-based column index to Excel column letters (1 -> 'A', 27 -> 'AA').
letters = '';
while colIdx > 0
    remainder = mod(colIdx - 1, 26);
    letters = [char('A' + remainder), letters]; %#ok<AGROW>
    colIdx = floor((colIdx - 1) / 26);
end

end

function closeExcelApp(excelApp)

try
    excelApp.Quit();
catch
end
try
    delete(excelApp);
catch
end

end

function oleColor = rgbToOleColor(r, g, b)

oleColor = r + g * 256 + b * 65536;

end
