function [gamma_est, R0_est, V_est, theta_discrete, W, y, OCV] = ...
    DRT_estimation_aug(t, ik, V_sd, lambda_hat, n, dt, dur, SOC, soc_values, ocv_values)
% DRT_estimation_aug estimates the gamma function and voltage using DRT
% with augmented internal resistance, employing i(k-1) for the RC update.
%
% Inputs:
%   t           - Time vector (length N)
%   ik          - Current vector (length N)
%   V_sd        - Measured voltage vector (length N)
%   lambda_hat  - Regularization parameter (scalar)
%   n           - Number of RC elements
%   dt          - Sampling time vector (length N), where dt(k)=t(k)-t(k-1)
%   dur         - Duration (tau_max) for tau range
%   SOC         - State of Charge vector (length N)
%   soc_values  - SOC values from SOC-OCV data
%   ocv_values  - Corresponding OCV values from SOC-OCV data
%
% Outputs:
%   gamma_est       - Estimated gamma vector (size n x 1)
%   R0_est          - Estimated internal resistance (scalar)
%   V_est           - Estimated voltage vector (length N)
%   theta_discrete  - Discrete theta values (size n x 1)
%   W               - Kernel matrix used in estimation (size N x n)
%   y               - Adjusted measured voltage (V_sd - OCV)
%   OCV             - Interpolated OCV vector (length N)

    % 1) Calculate OCV using SOC and soc_ocv data
    OCV = interp1(soc_values, ocv_values, SOC, 'linear', 'extrap');

    % 2) Define theta_discrete, tau_discrete
    tau_min = 0.1;  % Minimum tau value in seconds (example)
    tau_max = dur;  % Maximum tau value in seconds
    theta_min = log(tau_min);
    theta_max = log(tau_max);
    theta_discrete = linspace(theta_min, theta_max, n)';  % [n x 1]
    delta_theta = theta_discrete(2) - theta_discrete(1);
    tau_discrete = exp(theta_discrete);                  % [n x 1]

    % 3) Build the W matrix (using i(k-1) for k>=2)
    N = length(t);
    W = zeros(N, n);
    %
    %  첫 스텝: k_idx=1 에서는 k_idx-1=0이므로 전류 i(0)는 정의되지 않음.
    %  여기서는 초기값을 0으로 둠.
    %
    for k_idx = 1:N
        if k_idx == 1
            % Initialize W(1,i) = 0
            for i = 1:n
                W(k_idx, i) = 0;
            end
        else
            % Use i(k-1) for the "new input" term
            for i = 1:n
                % (dt(k_idx) = t(k_idx)-t(k_idx-1))
                %  W(k_idx-1, i) = previous step's w value
                W(k_idx, i) = W(k_idx-1, i) * exp(-dt(k_idx) / tau_discrete(i)) ...
                    + ik(k_idx-1) * (1 - exp(-dt(k_idx) / tau_discrete(i))) * delta_theta;
            end
        end
    end

    % 4) Augment W with the current vector ik (for R0 estimation)
    %    Note: we still use the current 'ik(k)' (the present sample) for the ohmic drop
    %    in the final model. Typically that's consistent with V_sd(k) = OCV(k) + i(k)*R0 + ...
    W_aug = [W, ik(:)];  % [N x (n+1)]

    % 5) Adjust y (measured voltage minus OCV)
    y = V_sd - OCV;
    y = y(:);  % ensure column vector

    % 6) Regularization matrix L (first-order difference)
    L = zeros(n-1, n);
    for i = 1:n-1
        L(i, i)   = -1;
        L(i, i+1) =  1;
    end

    % 7) Augment L (no regularization on R0)
    L_aug = [L, zeros(n-1, 1)];  % [ (n-1) x (n+1) ]

    % 8) Set up the quadratic programming problem
    %    Minimizing J = ||y - W_aug * params||^2 + lambda_hat * ||L_aug*params||^2
    %    => H = 2(W_aug'W_aug + lambda_hat L_aug'L_aug), f = -2 W_aug'y
    H = 2 * (W_aug' * W_aug + lambda_hat * (L_aug' * L_aug));
    f = -2 * W_aug' * y;

    % 9) Inequality constraints: params >= 0  (gamma_i >= 0, R0 >= 0)
    A_ineq = -eye(n+1);
    b_ineq = zeros(n+1, 1);

    % 10) Solve the quadratic programming problem
    options = optimoptions('quadprog', 'Display', 'off');
    params = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

    % 11) Extract gamma_est, R0_est
    gamma_est = params(1:end-1);  % [n x 1]
    R0_est = params(end);

    % 12) Compute the estimated voltage
    %     V_est(k) = OCV(k) + W_aug(k,:) * params
    V_est = OCV + W_aug * params;

end
