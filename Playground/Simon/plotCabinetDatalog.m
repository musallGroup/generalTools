function plotCabinetDatalog(dataFolder)
% PLOT_DATALOG_MONTHLY  Read daily CSV log files and plot monthly summaries
% tuned for columns: Date (string yyyy/MM/dd), Time (duration),
% Temperature, Rel. Humidity.

if nargin < 1 || ~isfolder(dataFolder)
    dataFolder = uigetdir(pwd, 'Select folder with CSV log files');
    if isequal(dataFolder, 0); return; end
end

files = dir(fullfile(dataFolder, '*.csv'));
if isempty(files)
    error('No CSV files found in: %s', dataFolder);
end

allDT = datetime.empty(0,1);
allT  = [];
allRH = [];

for k = 1:numel(files)
    fp = fullfile(files(k).folder, files(k).name);

    % Keep original headers so we can use 'Rel. Humidity'
    opts = detectImportOptions(fp, 'VariableNamingRule','preserve');

    % Ensure expected types
    if any(strcmp(opts.VariableNames, 'Date'))
        opts = setvartype(opts, 'Date', 'string');
    end
    if any(strcmp(opts.VariableNames, 'Time'))
        % Prefer duration; if it's text in some files, we�ll fix below
        opts = setvartype(opts, 'Time', 'duration');
    end

    T = readtable(fp, opts);

    % --- Build datetime from Date (string 'yyyy/MM/dd') and Time (duration or text)
    try
        d = datetime(T.Date, 'InputFormat','yyyy/MM/dd');  % <� your format
    catch
        d = datetime(T.Date, 'InputFormat','MM/d/yyyy');  % <� your format
    end

    if isduration(T.Time)
        t = T.Time;
    else
        % fallback: parse text like '23:56:52'
        t = duration(string(T.Time), 'InputFormat','hh:mm:ss');
    end

    dt = d + t;  % datetime + duration

    % --- Read values
    temp = double(T.Temperature);
    rh   = double(T.('Rel. Humidity'));  % dotted name requires parentheses

    % Remove bad rows
    bad = isnat(dt) | isnan(temp) | isnan(rh);
    dt(bad) = []; temp(bad) = []; rh(bad) = [];

    allDT = [allDT; dt]; %#ok<AGROW>
    allT  = [allT;  temp]; %#ok<AGROW>
    allRH = [allRH; rh];   %#ok<AGROW>
end

if isempty(allDT)
    error('No valid rows parsed. Check the files.');
end

% Sort & deduplicate timestamps
[allDT, idx] = sort(allDT);
allT  = allT(idx);
allRH = allRH(idx);
[~, uidx] = unique(allDT, 'stable');
if numel(uidx) < numel(allDT)
    allDT = allDT(uidx); allT = allT(uidx); allRH = allRH(uidx);
end

% Group by month
Tkeys = table(year(allDT), month(allDT), 'VariableNames', {'Year','Month'});
[G, keys] = findgroups(Tkeys);

outDir = fullfile(dataFolder, 'monthly_plots');
if ~exist(outDir, 'dir'); mkdir(outDir); end

% Plot each month
for g = 1:max(G)
    msk = (G == g);
    dt_g  = allDT(msk);
    t_g   = allT(msk);
    rh_g  = allRH(msk);

    if numel(dt_g) < 3, continue; end

    f = figure('Color','w','Position',[100 100 1100 420]);

    yyaxis left
    plot(dt_g, t_g, '-', 'LineWidth', 1.3)
    ylabel('Temperature')
    grid on
    ylim([19 25]);

    yyaxis right
    plot(dt_g, rh_g, '-', 'LineWidth', 1.3)
    ylabel('Rel. Humidity (%)')

    yyyy = table2array(keys(g,1)); mm = table2array(keys(g,2));
    title(sprintf('Temperature & Humidity � %04d-%02d', yyyy, mm))
    xlabel('Date/Time')
    ylim([0 100]);

    % readable ticks
    ax = gca;

    % Round to whole days and pick one tick per day at noon
    dayStart = dateshift(min(dt_g), 'start', 'day');
    dayEnd   = dateshift(max(dt_g), 'start', 'day');
    xt = (dayStart:dayEnd) + hours(9);  % daily ticks at noon

    ax.XTick = xt;
    ax.XTickLabel = cellstr(datestr(xt, 'dd-mmm'));  % e.g. '28-May'
    ax.XLim = [min(dt_g) max(dt_g)];


    xlim([min(dt_g) max(dt_g)] + seconds([-30 30]))

    exportgraphics(f, fullfile(outDir, sprintf('monthly_%04d-%02d.png', yyyy, mm)), ...
        'Resolution', 150);
    close(f);
end

fprintf('Done. PNGs saved in: %s\n', outDir);
end
