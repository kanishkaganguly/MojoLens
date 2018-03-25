%% Wifi Localization
% Authors: Nitin J Sanket, Chahat Deep Singh, Kanishka Ganguly

clc; clear; close all;

NumRouters = 4;
RSSI = zeros(100,200);

figure,
imagesc(RSSI);
colormap jet

[x, y] = ginput(NumRouters);
[C, R] = meshgrid(1:size(RSSI,2), 1:size(RSSI,1));

Dist = zeros(size(RSSI,1), size(RSSI,2), NumRouters);
for count = 1:NumRouters
    Dist(:,:,count) = -sqrt((C-x(count)).^2 + (R-y(count)).^2);
end

DistSum = sum(Dist, 3);

% figure,
imagesc(DistSum);
colormap jet

RSSIObs = [-50, -50, -50, -50];
ErrorCov = 20;

%%
for count = 1:NumRouters
    Mask(:,:,:,count) = repmat((Dist(:,:,count) > RSSIObs(count) - ErrorCov/2) & (Dist(:,:,count) <= RSSIObs(count)+ErrorCov/2),1,1,1);
end

figure,
montage(Mask);
% imshow(Mask(:,:,1));

MaskAll = sum(Mask, 4);

figure,
imagesc(MaskAll);