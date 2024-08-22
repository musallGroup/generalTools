function [cids, cgs] = readClusterGroupsTSV(filename, sorterType)
%function [cids, cgs] = readClusterGroupsTSV(filename)
% cids is length nClusters, the cluster ID numbers
% cgs is length nClusters, the "cluster group":
% - 0 = noise
% - 1 = mua
% - 2 = good
% - 3 = unsorted
% - 4 = pMUA
% - 5 = pSUA

if ~exist('sorterType', 'var') || isempty(sorterType)
    sorterType = 'Phy';
end

fid = fopen(filename);
C = textscan(fid, '%s%s');
fclose(fid);

cids = cellfun(@str2num, C{1}(2:end), 'uni', false);
ise = cellfun(@isempty, cids);
cids = [cids{~ise}];

isNoise = cellfun(@(x)strcmpi(x,'noise'),C{2}(2:end));
isMUA = cellfun(@(x)strcmpi(x,'mua'),C{2}(2:end));
isUns = cellfun(@(x)strcmp(x,'unsorted'),C{2}(2:end));
isProbMUA = cellfun(@(x)strcmp(x,'pMUA'),C{2}(2:end));
isProbSUA = cellfun(@(x)strcmp(x,'pSUA'),C{2}(2:end));

% if strcmpi(sorterType, 'phy')
%     isGood = cellfun(@(x)strcmpi(x,'good'),C{2}(2:end));
% elseif strcmpi(sorterType, 'sortingview')
%     isGood = cellfun(@(x)strcmpi(x,'SUA'),C{2}(2:end));
% end

%check if annotation follows phy or sortingview logic
a = cellfun(@(x)strcmpi(x,'good'),C{2}(2:end));
b = cellfun(@(x)strcmpi(x,'SUA'),C{2}(2:end));
if sum(a) > sum(b)
    isGood = a;
else
    isGood = b;
end
    
% create labels
cgs = zeros(size(cids), 'single');
cgs(isMUA) = 1;
cgs(isGood) = 2;
cgs(isUns) = 3;
cgs(isProbMUA) = 4;
cgs(isProbSUA) = 5;

% only return clusters with known labels
useIdx = isNoise | isMUA | isGood | isUns | isProbMUA | isProbSUA;
cids = cids(useIdx);
cgs = cgs(useIdx);


