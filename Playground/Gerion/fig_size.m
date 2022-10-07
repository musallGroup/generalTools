function fig = fig_size(fig, rel_rect)
if ~exist('fig', 'var')
    fig = gcf;
end

try
    set(fig, 'units', 'normal', 'OuterPosition', rel_rect);
catch
    % the default option
    set(fig, 'units', 'normal', 'OuterPosition', [0, 0, 1, 1]);
end
