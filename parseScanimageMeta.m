function [SI, jsonData] = parseScanimageMeta(metaText)
% function to decode scanimage metadata that was written to a TIF file.
% This first contains information from the matlab object SI (containing
% settings from scanimage) and from additional info in json formatting with
% additional information. The function returns this as two outpout
% variables 'SI' and 'jsonData'

% Step 1: Find the start of the JSON block (first '{' not part of a MATLAB line)
jsonStart = regexp(metaText, '[\r\n]+\s*\{', 'once');
if isempty(jsonStart)
    error('No JSON block found in the string.');
end

% Step 2: Split the string
matlabPart = strtrim(metaText(1:jsonStart-1));
jsonPart   = strtrim(metaText(jsonStart:end));

% Step 3: Create SI struct from MATLAB-style lines
SI = struct();
lines = splitlines(matlabPart);
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if ~isempty(line)
        try
            eval([line ';']);  % This updates SI directly
        catch
            % Fallback: parse as key and store RHS as raw string
            tokens = regexp(line, '^(SI\.[\w\.]+)\s*=\s*(.*)$', 'tokens', 'once');
            if ~isempty(tokens)
                key = tokens{1};
                val = strtrim(tokens{2});
                
                % Enclose string value in quotes if not already
                if ~(startsWith(val, "'") || startsWith(val, '"'))
                    val = ['''' val ''''];
                end
                
                % Assign as raw string
                try
                    eval([key ' = ' val ';']);
                catch e2
                    warning('Failed to assign key "%s". Error: %s', key, e2.message);
                end
            else
                warning('Could not parse line: %s', line);
            end
        end
    end
end

% Step 4: Parse JSON
jsonData = jsondecode(jsonPart);
