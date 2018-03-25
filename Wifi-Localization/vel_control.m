function U = vel_control(pose , pose_aim , param)
%	
%  [V_tra , V_rot] = vel_control(pose , pose_aim , param)				
%
%   Wheels control function of the robot
%
%	pose           [x ; y ; angle]
%	pose_aim       [x ; y ; angle]
%   param          Structure
%
%   Example
%   --------
%   pose             = [10 ; 11 ; 0.3];
%   pose_aim         = [10.5 ; 11.2 ; 0.32];
%
%   param.V_d        = 0;
%   param.R          = 0.09;
%   param.D          = 0.4;
%   param.V_max      = 5;       
%   param.Kp         = 0.9;
%   param.Kd         = 0.5;
%   param.V_t        = 7;
%   param.sigmadelta = 0.26;
%
%   [V_tra , V_rot] = vel_control(pose , pose_aim , param);
%   
%  Author : Sébastien PARIS : sebastien.paris@lsis.org, date : 10/09/2007
%  ------

tiny  = 0.0001;

U     = zeros(2 , 1);

dx    = (pose_aim(1) - pose(1));

dy    = (pose_aim(2) - pose(2));

theta = pose(3);

V_max = param.V_max;

D     = param.D;


dist  = sqrt(dx*dx + dy*dy);

angle = atan2(dy , dx);


if (dist < tiny)
    
    delta = 0;   
    
else
    
    delta = acos(real((dx*cos(theta) + dy*sin(theta))/dist));
    
end

if ( ( cos(theta + delta) - cos(angle) ).^2 + ( sin(theta + delta) - sin(angle) ).^2 > tiny )
    
    delta = -delta;
    
end

V_d   = param.Kp.*(delta + param.sigmadelta.*rand) + param.Kd.*param.V_d;

V_t   = V_max*0.5;

V_dd  = abs(V_d*0.5);


if ((V_dd + V_t) > V_max)
    
    if ((V_max - V_dd) > 0)
        
        V_t = (V_max - V_dd);
        
    else
        
        V_t = 0;
        
        V_d = min(2*V_max , V_d);
        
    end
    
elseif ( (V_t - V_dd) < 0)
    
    V_t = V_dd;
    
end


v_l          = max(min(V_max , 0.5*(V_t + V_d)) , 0); 

v_r          = max(min(V_max , 0.5*(V_t - V_d)) , 0); 


U(1)         = (v_l + v_r)*0.5;

U(2)         = (v_l - v_r)/D;
