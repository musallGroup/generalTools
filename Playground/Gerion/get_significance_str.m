function stats_str = get_significance_str(p)
if ~isnumeric(p)
    warning('Input is not numveric!');
    stats_str = 'n.a.';
    return
end

if p > 0.05
    stats_str = 'n.s.';
elseif p > 0.01
    stats_str = '*';
elseif p > 0.001
    stats_str = '**';
else
    stats_str = '***';
end

