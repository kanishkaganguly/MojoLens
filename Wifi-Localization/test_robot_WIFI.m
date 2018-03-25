% Demo illustrating localization of a robot by particle filter. 
% WiFi measurements are modeled by a Ray-Tracing engine allowing up to 3 walls'reflexion. Particle
% filter help to correct odometry'mesurements of the non-holonomoc robot trajectory.
% References : i) Jacques Beneat, http://www2.norwich.edu/jbeneat/ (Ray-tracing indoor propagation model)
%             ii) http://users.isr.ist.utl.pt/~vale/english/projects/pfilter/pfilter1.html for
% particle filter and non-holonomic trajectory
% 
%  Author : Sébastien PARIS : sebastien.paris@lsis.org, date : 10/09/2007





clear
clc
close all hidden,

map                      = 'norwich01.flp';
%map                     = 'simple2.flp';
flp                      = load_flp(map);

%% Particle filter parameters %%

d                        = 3;
flp.info.nr              = 1;          % Number of reflexion in the Ray-tracing engine
verbose                  = 2;          %0 (none), 1(map only) ,2(map + measurement) ,3(map + measurement+likelihood) ,4(map + measurement+likelihood+particle weights)
N                        = 5000;      % Number of particles
N_threshold              = (9.2/10)*N; % Redistribution threshold

%% Non-Holonomic parameters %%

param.dist_th            = 100;
param.V_max              = 5;
param.V_d                = 0.01;
param.Kd                 = 0.01;
param.Kp                 = 0.01;
param.sigmadelta         = 0.0001; %0.26; %State curve noise
param.R                  = 0.001; %0.09; %
param.T                  = 20; %0.05;
param.biais              = 0.0;
param.D                  = 0.4;
param.maxite             = 250;
param.maxK               = 3000;

%% Measurement covariance %%

cov_RSSI                 = (5*10e-6)^2; % True measurement covariance noise added
cov_Z                    = (5*10e-6)^2; % Assumed covariance noise for the PF

%% Initial state covariance %%

cov_x1                   = (5000)^2;
cov_y1                   = (5000)^2;
cov_theta1               = (pi/16)^2;

Q1                       = [cov_x1 , 0 , 0 ; 0 , cov_y1 , 0 ; 0 , 0 , cov_theta1];

%% state covariance %%

sigma2                   = (param.R*param.T)^2;
Qk                       = [(21/5)*sigma2 , (41/25)*sigma2 , (42/25)*sigma2 ; (41/25)*sigma2 , (21/5)*sigma2 , (42/25)*sigma2 ; (42/25)*sigma2 , (42/25)*sigma2 , (902/25)*sigma2];

%% plot floorplan %%

fig1                     = plot_flp(flp);

%% select way points %%


title('Select/add way points by left clicking (rigth click for the last wayoint)', 'fontsize' , 12);
Y                        = getline(fig1)';

hold on
plot(Y(1 , :) , Y(2 , :) , 'r-+' , 'linewidth' , 2);
drawnow

%% select beacons (wifi access) %%


title('select/add beacon'' positions by left click (right click for the last one)' , 'fontsize' , 12);

[x , y]                  = getpts;
temp                     = flp.geom.planes([3 , 6 , 9] , :);
zmin                     = min(temp(:));
zmax                     = max(temp(:));
temp                     = (zmax-zmin)/2;
flp.info.TXpoint         = [x' ; y' ; temp(: , ones(1 , length(x)))];
Nt                       = size(flp.info.TXpoint , 2);
 
plot(flp.info.TXpoint(1 , :) , flp.info.TXpoint(2 , :) , 'c*');
drawnow

%% Generate Nominal Non-holonomic trajectory from via points %%

[X_traj , U]             = generate_trajectory(Y , param);
K                        = size(X_traj , 2);
X1                       = X_traj(: , 1);

plot(X_traj(1 , :) , X_traj(2 , :) , 'k' , 'linewidth' , 2);
hold off
drawnow

%% Generate Measurements %%

Xtemp                     = [X_traj([1 , 2] , :) ; temp(: , ones(1 , size(X_traj , 2)))];
Z_perfect                 = total_power3(flp.info.TXpoint , Xtemp , flp.geom.planes , flp.geom.material , flp.info.fc , flp.info.nr);
Z                         = Z_perfect + sqrt(cov_RSSI)*randn(Nt , K);  %% add noise

%% Run Particle Filter %%

[X_pf , Pcov]             = pf_robot_WIFI(X1 , Q1 , U , Qk , Z , cov_Z , flp , param.T , N , N_threshold , verbose , Xtemp , Z_perfect);

