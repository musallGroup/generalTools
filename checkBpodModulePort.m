function foundModule = checkBpodModulePort(checkPort, moduleType)
% function to find bpod modules

foundModule = false;
response = [];

disp(['Testing port ' checkPort])
if strcmpi(moduleType, 'wavePlayer')
    try
        cPort = serialport(checkPort, 115200, 'TimeOut', 0.1);
        cPort.write(227, 'uint8');
        response = cPort.read(1, 'uint8');
    end
        
    if isempty(response) || response ~= 228
        disp(['Could not connect to ' moduleType])
    else
        foundModule = true;
        disp(['Found ' moduleType ' on port ' checkPort])
    end

elseif strcmpi(moduleType, 'analogIn')
    try
        cPort = serialport(checkPort, 115200, 'TimeOut', 0.1);
        cPort.write([213 'O'], 'uint8');
        response = cPort.read(1, 'uint8');
    end

    if isempty(response) || response ~= 161
        disp(['Could not connect to ' moduleType])
    else
        foundModule = true;
        disp(['Found ' moduleType ' on port ' checkPort])
    end

end
clear cPort
