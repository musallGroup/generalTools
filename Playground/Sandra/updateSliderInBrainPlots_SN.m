function updateSliderInBrainPlotsSN(src, event, hText, connections, corr_connections, line_strengths, color_list, transparency, iSeg, center_per_region, opts)
    frameIdx = round(get(src, 'Value')); % Get slider value
    for i = 1:size(corr_connections{iSeg}{1}, 1)
        i_reg = corr_connections{iSeg}{1}(i, 1);
        j_reg = corr_connections{iSeg}{1}(i, 2);

        if i_reg == j_reg
            set(connections{i}, 'SizeData', line_strengths(1) * corr_connections{iSeg}{3}(i, frameIdx), 'CData', reshape(color_list(i, frameIdx, 1:3), [1, 3]), 'MarkerFaceAlpha', transparency(i, frameIdx));
        else
            x_coord = [center_per_region{i_reg}(2), center_per_region{j_reg}(2)];
            y_coord = [center_per_region{i_reg}(1), center_per_region{j_reg}(1)];
            set(connections{i}, 'LineWidth', line_strengths(2) * corr_connections{iSeg}{3}(i, frameIdx), 'Color', reshape(color_list(i, frameIdx, :), [1, 4]));
        end
    end

    set(connections{i+1}, 'XData', opts.tC(frameIdx), 'Ydata', opts.Corr_strength{iSeg}(frameIdx)); % Update image

    set(hText, 'String', sprintf('Frame %d', frameIdx)); % Update text
end
