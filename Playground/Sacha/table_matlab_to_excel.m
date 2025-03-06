
load('C:\Users\abourachid\images _by_order_2853\processed\transformations\FluoQuantification\FluorescenceMatrixCumulative.mat')

% cell2table(fluorescenceMatrix(:, 2:end)', "VariableNames", fluorescenceMatrix(:, 1)')
t = cell2table(fluorescenceMatrix');

writetable(t, "Test.table.xlsx")
