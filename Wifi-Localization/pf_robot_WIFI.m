function [Xmean , Pcov , N_eff] = pf_robot_WIFI(X1 , Q1 , U , Qk , Z , cov_Z , flp , T , N , N_threshold , verbose , X_traj , Z_traj)

%  Particle filter for robot localization using wifi measurements.
%
%  Usage
%  ------
%
%  [Xmean , Pcov , N_eff] = pf_robot_WIFI(X1 , Q1 , U , Qk , Z , cov_Z , flp , T , N , N_threshold , verbose , X_traj , Z_traj);
%
%
%
%  Inputs
% ---------
%
% X1             Initial State (d x 1), d = 3
% Q1             Initial Sate Covariance (d x d)
% U              Control Low (2 x K - 1), [Vt ; Vr]
% Qk             State Covariance
% Z              Wifi measurements (Nt x K)
% cov_Z          Measurement covariance (m x m)
% flp            Floor Plan structure
% T              Sampling time
% N              Number of particules
% N_threshold    Resampling threshold, fraction of N
% verbose        0 : no display, 1 display map + particule, 2 add
%                measurements views, 3 add likelihood, 4 add view of
%                particles weights
%
%  Outputs
% ----------
% Xmean          MMSE Estimates (d x K)
% Pcov           Coviariances estimates (d x d x K)
% N_eff          Instant of resampling
%
%
%  Author : S�bastien PARIS : sebastien.paris@lsis.org, date : 10/09/2007
%  ------


warning off

if (nargin < 9)
    N = 5000;
end
if (nargin < 10)
    N_threshold = (8/10)*N;
end
if (nargin < 11)
    verbose = 0;
end
if(nargin < 13) 
    Z_traj = [];
end

if(isempty(Z_traj) && verbose > 1)
    
    disp('Z_traj is empty, switching verbose = 0')
    
    verbose = 0;
    
end


d                = size(X1 , 1);

m                = size(Z , 1);

K                = size(U , 2) + 1;


%%%%%%%%%%% Memory Allocation %%%%%%%%%%%

Xmean            = zeros(d , K);

Pcov             = zeros(d , d , K);

N_eff            = zeros(1 , K);

ON               = ones(1 , N);

TN               = T(ON);

tiny             = 10e-30;

cteE             = 1/(2*pi)^(m*0.5);

cteN             = 1/N;

vectN            = cteN(ON);

Zpf              = zeros(m , K);

PcovZ            = zeros(m , m , K);

resZ             = zeros(1 , K);

resE             = zeros(1 , K);

temp             = flp.geom.planes([3 , 6 , 9] , :);
    
zmin             = min(temp(:));
 
zmax             = max(temp(:));

temp             = (zmax-zmin)/2;

Otemp            = temp(: , ON);



%%%%%%%%%%% Memory Allocation %%%%%%%%%%%

w                = vectN;

Ck               = chol(Qk)';

compteur         = 0;


if (verbose > 0)


    temp                     = flp.geom.planes([1 , 4 , 7] , :);
    x_min                    = min(temp(:));
    x_max                    = max(temp(:));

    temp                     = flp.geom.planes([2 , 5 , 8] , :);
    y_min                    = min(temp(:));
    y_max                    = max(temp(:));



    offset                   = 500;
    Hp                       = [1 0 0 ; 0 1 0 ];
    alpha                    = 2.4477; %sqrt(chi2inv(0.95 , 2))

    xx                       = [flp.geom.planes(1,:) ; flp.geom.planes(4,:) ; flp.geom.planes(7,:) ; flp.geom.planes(10,:) ; flp.geom.planes(1,:)];
    yy                       = [flp.geom.planes(2,:) ; flp.geom.planes(5,:) ;  flp.geom.planes(8,:) ;  flp.geom.planes(11,:) ;  flp.geom.planes(2,:)];

    fig1                     = figure(1);

    set(fig1 , 'renderer' , 'zbuffer');
    set(fig1 , 'doublebuffer' , 'on');
    set(fig1  , 'nextplot' , 'replacechildren');


end

if (verbose > 1)
  
    time             = (0 : K - 1)*T;

    min_Z            = min(Z(:));
    max_Z            = max(Z(:));

    fig2             = figure(2);

    set(fig2 , 'renderer' , 'zbuffer');
    set(fig2 , 'doublebuffer' , 'on');
    set(fig2  , 'nextplot' , 'replacechildren');

end

if (verbose > 2)

    fig3             = figure(3);

    min_like         = 0.8*10e-30;
    max_like         = 5*cteE;

    set(fig3 , 'renderer' , 'zbuffer');
    set(fig3 , 'doublebuffer' , 'on');
    set(fig3  , 'nextplot' , 'replacechildren');

    axis([0 , time(end) , min_like , max_like])

end


if (verbose > 3)


    fig4          = figure(4);

    min_w         = 10e-50;
    max_w         = 5/N;

    set(fig4 , 'renderer' , 'zbuffer');
    set(fig4 , 'doublebuffer' , 'on');
    set(fig4  , 'nextplot' , 'replacechildren');

    axis([1 , N , min_w , max_w])

end

%%%%%%%%%%%%%%%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%

k                                 = 1;

%----------------------- Xpart k = 1 -----------------------%

Xpart                             = X1(: , ON) + chol(Q1)'*randn(d , N);

%----------------------- Likelihood ------------------------%

Xtemp                             = [Xpart([1 , 2] , :) ; Otemp];

[likelihood , Zpart]              = likelihood_power2(Z(: , k) , flp.info.TXpoint,  Xtemp  ,  flp.geom.planes , flp.geom.material , flp.info.fc  , cov_Z , flp.info.nr);

%----------------------- Update Weight ---------------------%

w                                 = w.*likelihood;

w                                 = w/sum(w);

%----------------------- Xmean & Pcov ---------------------%


[Xmean(: , k) , Pcov(: , : , k)]  = part_moment(Xpart , w);

[Zpf(: , k) , PcovZ(: , : , k)]   = part_moment(Zpart , w);

%[Zpf(: , k) , PcovZ(: , : , k)]   = part_moment(Zpart , vectN);


temp                              = (Z(: , k) - Zpf(: , k));

resZ(k)                           = temp'*inv(PcovZ(: , : , k))*temp;

resE(k)                           = (cteE/sqrt(abs(det(PcovZ(: , : , k)))))*exp(-0.5*resZ(k)) + tiny;



if (verbose >3 )

    figure(fig4)

    plot(w);

    axis([1 , N ,  min_w , max_w])

    title(sprintf('k = %d/%d' , k , K));

end


if (verbose > 0)

    fig1                        = figure(1);

    [x ,  y]                    =  ndellipse(Xmean(: , k) , Pcov(: , : , k) ,  Hp  , alpha);

    plot(xx , yy, 'k')
    
    hold on

    plot(flp.info.TXpoint(1 , :) , flp.info.TXpoint(2 , :) , 'c*');

    plot(Xpart(1 , :) , Xpart(2 , :) , 'k.' , 'markersize' , 6 , 'linewidth' , 2);

    plot(X_traj(1 , k)  , X_traj(2 , k) , 'g' , 'markersize' , 6 , 'linewidth' , 2);

    plot(Xmean(1 , k)   , Xmean(2 , k) , 'r' , 'markersize' , 6 , 'linewidth' , 2);

    plot(x   , y , 'y' , 'markersize' , 6 , 'linewidth' , 2);

    hold off
    
    axis([x_min-offset ,  x_max+offset , y_min-offset ,  y_max+offset])

    title(sprintf('k = %d/%d, N_{eff} = %6.2f/%d, Redistribution = %d' , k , K , N_eff(k) , N_threshold, compteur));


end

if (verbose > 1)


    fig2                        = figure(2);

    plot(0 , Z(: , k));

    hold on

    plot(0 , Z_traj(: , k)', 'g'  , 'linewidth' , 2);

    plot(0 , Zpf(: , k)' , 'r' , 'linewidth' , 2);

    hold off

    title(sprintf('dist(Z_{pf},Z_{true}) = %8.4f' , resZ(1)));

    axis([0 , time(end) , min_Z , max_Z])

end

if (verbose > 2)

    figure(fig3)

    semilogy(0 , resE(k), 'k' ,  'linewidth' , 2);

    axis([0 , time(end) ,  min_like , max_like])

end

drawnow


%%%%%%%%%%%%%%%%%%%% Iterations %%%%%%%%%%%%%%%%%%%%

for k = 2 : K

    %-------------------------------------- Prediction -----------------------%

    %    Xpart                             = Xpart + reshape(ndtimes(reshape([T*cos(Xpart(3 , :)) ;  T*sin(Xpart(3 , :)) ; Z3T ] , 3 , 2 , N) , U(: , k - 1)) , 3 , N) + Ck*randn(d , N);

    cte                               = U(1 , k - 1)*T;

    Xpart                             = Xpart + [cte*cos(Xpart(3 , :)) ; cte*sin(Xpart(3 , :)) ; TN*U(2 , k - 1)] + Ck*randn(d , N);


    %Xpart_{k}                        = Xpart_{k-1} + F(Xpart_{k-1},U_{k-1}) + W_{k-1}

    %-------------------------------------- Likelihood ---------------------%

    Xtemp                             = [Xpart([1 , 2] , :) ; Otemp];

    [likelihood , Zpart]              = likelihood_power2(Z(: , k) , flp.info.TXpoint , Xtemp  ,  flp.geom.planes , flp.geom.material , flp.info.fc  , cov_Z , flp.info.nr);

    %------------------------------------- Update weight --------------------%

    w                                 = w.*likelihood;

    w                                 = w/sum(w);

    %-------------- MMSE estimate & Weighted covariance ---------------

    [Xmean(: , k) , Pcov(: , : , k)]  = part_moment(Xpart , w);

    [Zpf(: , k) , PcovZ(: , : , k)]   = part_moment(Zpart , w);

    %[Zpf(: , k) , PcovZ(: , : , k)]   = part_moment(Zpart , vectN);


    temp                              = (Z(: , k) - Zpf(: , k));

    resZ(k)                           = temp'*inv(PcovZ(: , : , k))*temp;

    resE(k)                           = (cteE/sqrt(abs(det(PcovZ(: , : , k)))))*exp(-0.5*resZ(k)) + tiny;



    if (verbose >3)

        figure(fig4)

        plot(w);

        axis([1 , N ,  min_w , max_w])

        title(sprintf('k = %d/%d' , k , K));

    end

    %----------------- Particle Resampling -------------------------

    N_eff(k)                          = 1/sum(w.*w);

    if (N_eff(k) < N_threshold)

        compteur                        = compteur + 1;

        indice_resampling               = particle_resampling(w);

        Xpart                           = Xpart(: , indice_resampling);

        w                               = vectN;

    end

    if (verbose > 0)


        ind_k                       = (1:k);

        fig1                        = figure(1);

        [x ,  y]                    = ndellipse(Xmean(: , k) , Pcov(: , : , k) ,  Hp  , alpha);

        plot(xx , yy , 'k')
        
        hold on
                
        plot(flp.info.TXpoint(1 , :) , flp.info.TXpoint(2 , :) , 'c*');

        plot(Xpart(1 , :) , Xpart(2 , :) , 'k.' , 'markersize' , 6 , 'linewidth' , 2);

        plot(X_traj(1 , ind_k)  , X_traj(2 , ind_k) , 'g' , 'markersize' , 6 , 'linewidth' , 2);

        plot(Xmean(1 , ind_k) , Xmean(2 , ind_k) , 'r' , 'markersize' , 6 , 'linewidth' , 2);
        
        plot(x , y , 'y' , 'markersize' , 6 , 'linewidth' , 2);
        
        hold off

        axis([x_min-offset ,  x_max+offset , y_min-offset ,  y_max+offset])

        title(sprintf('k = %d/%d, N_{eff} = %6.2f/%d, Redistribution = %d' , k , K , N_eff(k) , N_threshold, compteur));


    end

    if (verbose > 1)

        ind_k   = (1 : k);

        figure(fig2)

        plot(time(ind_k) , Z(: , ind_k)' );

        hold on

        plot(time(ind_k) , Z_traj(: , ind_k)','g' , 'linewidth' , 2);

        plot(time(ind_k) , Zpf(: , ind_k)', 'r' , 'linewidth' , 2);

        hold off

        axis([0 , time(end) , min_Z , max_Z])

        title(sprintf('dist(Z_{pf},Z_{true}) = %8.4f' , resZ(k)));

    end

    if (verbose > 2)

        figure(fig3)

        semilogy(time(ind_k) , resE(ind_k), 'k' , 'linewidth' , 2);

        axis([0 , time(end) ,  min_like , max_like])

    end

    drawnow

end


warning on
