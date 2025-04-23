function [gamma_est,R0_est,V_est,theta,tau,W_aug,y,OCV] = ...
         DRT_estimation_aug(t,ik,V_sd,lambda_hat,n,dur,SOC, ...
                            soc_values,ocv_values)
%DRT_ESTIMATION_AUG  Estimate Distribution of Relaxation Times (gamma) and
%ohmic resistance R0 from a voltage–current trajectory.
%
% Inputs
%   t, ik, V_sd   : column vectors (time [s], current [A], voltage [V])
%   lambda_hat    : regularisation weight
%   n             : number of discrete tau grid points
%   dur           : tau_max [s]
%   SOC           : state of charge vector (0–1)
%   soc_values,
%   ocv_values    : reference SOC–OCV table
%
% Outputs
%   gamma_est     : gamma(theta) (n×1)
%   R0_est        : ohmic resistance [ohm]
%   V_est         : fitted voltage (N×1)
%   theta, tau    : grids
%   W_aug, y, OCV : intermediates

% ----- ensure column vectors --------------------------------------------
t   = t(:);  ik = ik(:);  V_sd = V_sd(:);  SOC = SOC(:);
N   = numel(t);

% ----- OCV correction ----------------------------------------------------
OCV = interp1(soc_values(:),ocv_values(:),SOC,'linear','extrap');
y   = V_sd - OCV;

% ----- theta / tau grid --------------------------------------------------
tau_min = 0.1;           % [s]
tau_max = dur;
theta   = linspace(log(tau_min),log(tau_max),n).';
tau     = exp(theta);
dtheta  = theta(2)-theta(1);

% ----- build convolution matrix W ---------------------------------------
W  = zeros(N,n);
dt = [0 ; diff(t)];

for i = 1:n
    a      = exp(-dt./tau(i));
    w_prev = 0;
    for k = 1:N
        w_curr = a(k)*w_prev + ik(k)*(1-a(k))*dtheta;
        W(k,i) = w_curr;
        w_prev = w_curr;
    end
end

% ----- augmented matrix (R0 column) -------------------------------------
W_aug = [W , ik];                % size N×(n+1)

% ----- first‑order diff regularisation ----------------------------------
L     = spdiags([-ones(n,1) ones(n,1)],[0 1],n-1,n);
L_aug = [L , sparse(n-1,1)];     % no penalty on R0

% ----- quadratic programming --------------------------------------------
H = 2*(W_aug.'*W_aug + lambda_hat*(L_aug.'*L_aug));
f = -2*(W_aug.'*y);

A = -eye(n+1);                   % params ≥ 0
b = zeros(n+1,1);

opts   = optimoptions('quadprog','Display','off');
params = quadprog(H,f,A,b,[],[],[],[],[],opts);

gamma_est = params(1:n);
R0_est    = params(end);

% ----- voltage reconstruction -------------------------------------------
V_est = OCV + W_aug*params;
end
