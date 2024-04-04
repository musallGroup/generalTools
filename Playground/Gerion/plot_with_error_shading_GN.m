function hndl = plot_with_error_shading_GN(x, data, error, alpha, cl, patch_cl, keep_all_hndls)
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
if ~exist("keep_all_hndls", "var"); keep_all_hndls = 0; end


% ensure compatible shape
x = vec(x);
data = vec(data);
if min(size(error, 1:2)) > 1
    if size(error, 1) == 2
        error = error';
%     elseif size(error, 2) == 2
%         error = error;
    elseif not(size(error, 2) == 2)
        error("unexpected shape of var: error!");
    end
else
    error = cat(2, -vec(error), vec(error));
end

% patch([x; flip(x)], [data + error; flip(data - error)], "EdgeAlpha", 0, "FaceAlpha", alpha);
if keep_all_hndls
    patch([x; flip(x)], [data + error(:, 1); flip(data + error(:, 2))], patch_cl, "EdgeAlpha", 0, "FaceAlpha", alpha, "HandleVisibility", "off"); hold on;
else
    patch([x; flip(x)], [data + error(:, 1); flip(data + error(:, 2))], patch_cl, "EdgeAlpha", 0, "FaceAlpha", alpha); hold on;
end
hndl = plot(x, data, "Color", cl, "LineWidth", 1.5);


