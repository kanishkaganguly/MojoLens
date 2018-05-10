%% Wifi Localization
% Authors: Nitin J Sanket, Chahat Deep Singh, Kanishka Ganguly

clc; clear; close all;

I = imread('out_img.jpg');

NumRouters = 4;
RSSI = zeros(size(I,1),size(I,2));

I = imread('out_img.jpg');
%figure,
%imagesc(I);
% colormap jet

load('Data.mat');
% [x, y] = ginput(NumRouters);
[C, R] = meshgrid(1:size(RSSI,2), 1:size(RSSI,1));

Dist = zeros(size(RSSI,1), size(RSSI,2), NumRouters);
for count = 1:NumRouters
    Dist(:,:,count) = -sqrt((C-x(count)).^2 + (R-y(count)).^2);
end

DistSum = sum(Dist, 3);

% figure,
% imshow(I);

hold on;
imagesc(DistSum);
colormap jet
alpha(0.5);

RSSIObs = [-70, -20, -180, -120];
ErrorCov = 30;

%%
for count = 1:NumRouters
    Mask(:,:,:,count) = repmat((Dist(:,:,count) > RSSIObs(count) - ErrorCov/2) & (Dist(:,:,count) <= RSSIObs(count)+ErrorCov/2),1,1,1);
end

% figure,
% montage(Mask);
% imshow(Mask(:,:,1));

MaskAll = sum(Mask, 4);

figure,
imshow(I);
hold on;
imagesc(MaskAll);
alpha(0.5);
colormap jet