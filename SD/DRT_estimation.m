function [gamma_est, V_est, theta_discrete, tau_discrete, W, y] = DRT_estimation(t, ik, V_sd, lambda, n, dt, ~, OCV, R0)
    % DRT_estimation estimates the gamma function and voltage using DRT.
    %
    % Inputs:
    %   t           - Time vector
    %   ik          - Current vector
    %   V_sd        - Measured voltage vector
    %   lambda_hat  - Regularization parameter
    %   n           - Number of RC elements
    %   dt          - Sampling time (scalar or vector)
    %   dur         - Duration (tau_max)
    %   OCV         - Open Circuit Voltage
    %   R0          - Initial resistance
    %
    % Outputs:
    %   gamma_est       - Estimated gamma vector
    %   V_est           - Estimated voltage vector
    %   theta_discrete  - Discrete theta values
    %   tau_discrete    - Discrete tau values
    %   W               - Matrix used in estimation

    % Check if dt is scalar or vector
    if isscalar(dt)
        % If dt is scalar, create a vector of the same length as t
        dt = repmat(dt, length(t), 1);
    elseif length(dt) ~= length(t)
        error('Length of dt must be equal to length of t if dt is a vector.');
    end

    % Define theta_discrete and tau_discrete based on dur and n
    tau_min = 0.1;  % Minimum tau value in seconds
    tau_max = 1000;   % Maximum tau value in seconds % dur --> 1000 변경
    tau_max = 1000;   % Maximum tau value in seconds
    theta_min = log(tau_min);
    theta_max = log(tau_max);
    theta_discrete = linspace(theta_min, theta_max, n)';
    delta_theta = theta_discrete(2) - theta_discrete(1);
    tau_discrete = exp(theta_discrete);

    % Set up the W matrix
    W = zeros(length(t), n);
    for k_idx = 1:length(t)
        if k_idx == 1
            for i = 1:n
                W(k_idx, i) = ik(k_idx) * (1 - exp(-dt(k_idx) / tau_discrete(i))) * delta_theta;
            end
        else
            for i = 1:n
                W(k_idx, i) = W(k_idx-1, i) * exp(-dt(k_idx) / tau_discrete(i)) + ...
                              ik(k_idx) * (1 - exp(-dt(k_idx) / tau_discrete(i))) * delta_theta;
            end
        end
    end

    % Adjust y (measured voltage)
    y = V_sd - OCV - R0 * ik;

    % Regularization matrix L (first-order difference)
    L = zeros(n-1, n);
    for i = 1:n-1
        L(i, i) = -1;
        L(i, i+1) = 1;
    end

    % Set up the quadratic programming problem
    H = 2 * (W' * W + lambda * (L' * L));
    f = -2 * W' * y;

    % Inequality constraints: gamma >= 0
    A_ineq = -eye(n);
    b_ineq = zeros(n, 1);

    % Solve the quadratic programming problem
    options = optimoptions('quadprog', 'Display', 'off');
    gamma_est = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

    % Compute the estimated voltage
    V_est = OCV + R0 * ik + W * gamma_est;
end
