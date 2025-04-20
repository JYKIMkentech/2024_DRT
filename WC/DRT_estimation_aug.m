function [gamma_est,R0_est,V_est,theta,tau,W_aug,y,OCV] = ...
         DRT_estimation_aug(t,ik,V_sd,lambda_hat,n,dur,SOC, ...
                            soc_values,ocv_values)
%DRT_ESTIMATION_AUG  Estimate Distribution of Relaxation Times (gamma) and
%ohmic resistance R0 for a voltage‑current trajectory.
%
% Inputs
%   t            - time vector  [s]   (column)
%   ik           - current vector [A] (column, discharge < 0)
%   V_sd         - terminal voltage  [V] (column)
%   lambda_hat   - regularisation weight
%   n            - number of discrete tau grid points
%   dur          - tau_max  [s]
%   SOC          - state of charge vector (0...1) (column)
%   soc_values   - SOC grid for OCV table
%   ocv_values   - corresponding OCV values
%
% Outputs
%   gamma_est    - gamma(theta)  (n x 1, theta = ln tau)
%   R0_est       - ohmic resistance estimate  [ohm]
%   V_est        - reconstructed voltage  [V] (column)
%   theta        - theta grid  (n x 1)
%   tau          - tau grid    (n x 1)
%   W_aug        - convolution matrix with extra current column
%   y            - V_sd - OCV   [V] (column)
%   OCV          - interpolated open‑circuit voltage  [V] (column)
%
% Non‑negativity (gamma >= 0, R0 >= 0) enforced via quadprog.

% -------- 0) Ensure column vectors ---------------------------------------
t   = t(:);
ik  = ik(:);
V_sd = V_sd(:);
SOC  = SOC(:);
N = numel(t);

% -------- 1) OCV correction ----------------------------------------------
OCV = interp1(soc_values(:), ocv_values(:), SOC, 'linear', 'extrap');
y   = V_sd - OCV;     % length N

% -------- 2) theta / tau grid --------------------------------------------
tau_min = 0.1;          % [s]
tau_max = dur;
theta   = linspace(log(tau_min), log(tau_max), n).';
tau     = exp(theta);
dtheta  = theta(2) - theta(1);

% -------- 3) Build convolution matrix W ----------------------------------
W  = zeros(N,n);
dt = [t(1); diff(t)];

for i = 1:n
    a = exp(-dt./tau(i));     % decay factors
    w_prev = 0;
    for k = 1:N
        w_curr   = a(k)*w_prev + ik(k)*(1 - a(k))*dtheta;
        W(k,i)   = w_curr;
        w_prev   = w_curr;
    end
end

% -------- 4) Augment with current column (R0) -----------------------------
W_aug = [W , ik];              % size N x (n+1)

% -------- 5) 1st‑order difference regularisation -------------------------
L  = spdiags([-ones(n,1) ones(n,1)],[0 1],n-1,n);   % (n-1) x n
L_aug = [L , sparse(n-1,1)];    % no penalty on R0

% -------- 6) Quadratic programming ---------------------------------------
H = 2*(W_aug.'*W_aug + lambda_hat*(L_aug.'*L_aug));
f = -2*(W_aug.'*y);

A = -eye(n+1);
b = zeros(n+1,1);

opts = optimoptions('quadprog','Display','off');
params = quadprog(H, f, A, b, [], [], [], [], [], opts);

gamma_est = params(1:n);
R0_est    = params(end);

% -------- 7) Voltage reconstruction --------------------------------------
V_est = OCV + W_aug*params;
end
