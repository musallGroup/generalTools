function hndl = plot_with_error_shading(x, data, error, alpha, cl, patch_cl)
% This function plots an average trace with error shading.

% % Example for test:
% x = 1:10;
% data = rand(10);
% error = std(data, [], 2);
% data = nanmean(data, 2);
% alpha = 0.15;

% set defaults
if ~exist("alpha", "var"); alpha = 0.15; end
if ~exist("cl", "var"); cl = "k"; end
if isnumeric(cl); cl = vec(cl)'; end

if ~exist("patch_cl", "var"); patch_cl = cl; end

% ensure compatible shape
x = vec(x);
data = vec(data);
error = vec(error);

% patch([x; flip(x)], [data + error; flip(data - error)], "EdgeAlpha", 0, "FaceAlpha", alpha);
patch([x; flip(x)], [data + error; flip(data - error)], patch_cl, "EdgeAlpha", 0, "FaceAlpha", alpha); hold on;
hndl = plot(x, data, "Color", cl, "LineWidth", 1.5);
