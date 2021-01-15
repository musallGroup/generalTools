function nBarweb(cData, cError, cColor)
       
if ~exist('cColor', 'var')
    cColor = 'b';
end

[ngroups,nbars] = size(cData);
if ngroups > 1
    groupwidth = min(0.8, nbars/(nbars + 1.5));
    for i = 1 : nbars
        xPos = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
        errorbar(xPos, cData(:,i), cError(:,i), 'k', 'linestyle', 'none'); hold on;
    end
else
    errorbar(1:nbars, cData, cError, 'k', 'linestyle', 'none');
end

if ishold == 0
    check=true;
    hold on;
else
    check = false;
end
bar(cData, 'FaceColor', cColor);

if check
    hold off;
end