function [Y , U] = generate_trajectory(X , param) % vehicle simulation

%  [Y , U] = generate_trajectory(X , param);
%
%  Inputs
% --------
%
%  X          control points [x ; y] (2 x N)
%  param      parameters structure
% 
%  param.dist_th     Distance acceptance to reach control point
%  param.Vmax        Maximum speed translation
%  param.V_d         Curvature Speed
%  param.Kd          Gain parameter on Curvature speed 
%  param.Kp          Angle noise Gain (variance ) parameter on Curvature speed 
%  param.sigmadelta  Angle standard deviation
%  param.R           wheel radii of robot
%  param.T           Time step integration
%  param.biais       Bias on position 
%  param.D           half width of robot. Control Curvature rate
%  param.maxite      Maximum iteration between each control points
%  param.maxK        Maximum length of the trajectory
%  
%   Example 1
%   ---------
% 
%   clf,axis ([-10 100 -1000 2000])
%   X          = getline(gcf)';
%   [Y , U]    = generate_trajectory(X);
%
%
%
%
%
% 
%   Example 1
%   ---------
% 
%   clf,axis ([1 9 1 9])
%   X                 = getline(gcf)';
%   param.dist_th    = 0.40;
%   param.V_max      = 5;       
%   param.V_d        = 0;
%   param.Kd         = 0.5;
%   param.Kp         = 0.9;
%   param.sigmadelta = 0.26;
%   param.R          = 0.09;
%   param.T          = 0.05;
%   param.biais      = 0.0;
%   param.D          = 0.4;
%   param.maxite     = 250;
%   param.maxK       = 2000;
%
%   [Y , U]    = generate_trajectory(X , param);
%   figure(1) , plot(X(1 , :) , X(2 , :) , 'k-' , Y(1 , :) , Y(2 , :) , 'r-')
%   figure(2) , plot(1:size(U , 2) , U(1 , :), 'k-' , 1:size(U , 2) , U(2 , :) , 'r-')
%
%
%   Example 2
%   ---------
% 
%   close all,axis ([1775 22100 0 8900]) %cm
%   X                = getline(gcf)';
%   param.dist_th    = 100;
%   param.V_max      = 5;       
%   param.V_d        = 0;
%   param.Kd         = 0.01;
%   param.Kp         = 0.01;
%   param.sigmadelta = 0.001;
%   param.R          = 0.0001;
%   param.T          = 50;
%   param.biais      = 0.0;
%   param.D          = 0.4;
%   param.maxite     = 250;
%   param.maxK       = 2000;
%    figure(1) , plot(X(1 , :) , X(2 , :) , 'r'), hold on
%   [Y , U]    = generate_trajectory(X , param);
%    figure(1) , plot(X(1 , :) , X(2 , :) , 'k-' , Y(1 , :) , Y(2 , :) , 'r-')
%   figure(2) , plot(1:size(U , 2) , U(1 , :), 'k-' , 1:size(U , 2) , U(2 , :) , 'r-')
%
%
%  Author : Sébastien PARIS : sebastien.paris@lsis.org, date : 10/09/2007
%  ------


if(nargin < 2)
    
    d_min            = min(sqrt(sum(diff(X , [] ,2).^2)));

    param.dist_th    = d_min/50;
    param.maxite     = 250;   
    param.T          = d_min/param.maxite;

    
    param.V_max      = 5;
    param.V_d        = 0;
    param.Kd         = 0.5;
    param.Kp         = 0.9;
    param.sigmadelta = 0.26;
    param.R          = 0.09;
    param.biais      = 0.0;
    param.D          = 0.4;
    param.maxK       = 2000;

end

Y                = zeros(3 , param.maxK);

U                = zeros(2 , param.maxK - 1);

[d , K]          = size(X);

dist_th          = param.dist_th;

biais            = param.biais;

T                = param.T;


if ((d ~= 2) || (K < 2))
    
    error('X must be (K x 2)');
    
end


if (param.R > 0)
    
    sigma2           = (param.R*param.T)^2;
    
    Qk               = [(21/5)*sigma2 , (41/25)*sigma2 , (42/25)*sigma2 ; (41/25)*sigma2 , (21/5)*sigma2 , (42/25)*sigma2 ; (42/25)*sigma2 , (42/25)*sigma2 , (902/25)*sigma2];
    
    Ck               = chol(Qk)';
    
else
    
    Ck               = zeros(3);
    
end


nxt_via_point    = 1;

k                = 1;



%%%%%%%%%% Initialization %%%%%%%

Y(: , k)         =  [X(: , nxt_via_point ) ;  atan2(X(2 , 2 ) - X(2 , 1 ) ,  X(1 , 2 ) - X(1 , 1 ) ) + param.sigmadelta*rand];



nxt_via_point    = nxt_via_point + 1;


while ((nxt_via_point <= K) && (k < param.maxK)) 
        
    pose_aim      = [X(: , nxt_via_point ) ;  atan2(X(2 , nxt_via_point ) - Y(2 , k) ,  X(1 , nxt_via_point ) - Y(1 , k) ) ];
    
    co            = 1;
    
    while(sqrt( (pose_aim(1) - Y(1 , k)).^2 + (pose_aim(2) - Y(2 , k)).^2) > dist_th)
        
        if (co > param.maxite)
            
            error(['Path generation not converging on control point ' int2str(nxt_via_point)]);
            
        end
                
        U(: , k)              = vel_control(Y(: , k) , pose_aim , param); 

        Y(: , k + 1)          = Y(: , k) + [T*cos(Y(3 , k)) , 0 ; T*sin(Y(3 , k)) 0 ; 0 ,  T]*U(: , k) + Ck*(randn(3 , 1) - biais);

        co                    = co + 1;
        
        k                     = k + 1;
        
%         plot(Y(1 , 1:k) , Y(2 , 1:k)) 
%         
%         pause
        
    end
    
    nxt_via_point   = nxt_via_point + 1;
    
end

%%%%% Outputs %%%%

k      = k - 1;

Y      = Y(: , 1 : k);

U      = U(: , 1 : k - 1); 
