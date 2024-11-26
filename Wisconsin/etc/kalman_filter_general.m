function [X_est, P_est, Vt_est] = kalman_filter_general(...
    X_prev, P_prev, ik, vk, dt_k, Config, ...
    unique_soc_values, unique_ocv_values, ...
    Q_params, R_noise, model_params)

% Unpack previous state estimate
X_est = X_prev;
P_est = P_prev;

% SOC prediction (Coulomb Counting)
SOC_pred = X_est(1) + (dt_k / (Config.cap * 3600)) * Config.coulomb_efficiency * ik;
SOC_pred = max(0, min(1, SOC_pred)); % Limit SOC between 0 and 1

% Initialize variables
state_dim = length(X_est);
A_k = eye(state_dim);
B_k = zeros(state_dim, 1);

if strcmp(model_params.model_type, 'RC')
    num_RC = model_params.num_RC;
    % ECM parameter interpolation
    R0_interp = model_params.F_R0(SOC_pred);
    R_interp = model_params.F_R(SOC_pred);
    C_interp = model_params.F_C(SOC_pred);

    % State transition matrix A and input matrix B
    for i = 1:num_RC
        R_i = R_interp(i);
        C_i = C_interp(i);
        A_k(1+i, 1+i) = exp(-dt_k / (R_i * C_i));
        B_k(1+i) = R_i * (1 - exp(-dt_k / (R_i * C_i)));
    end
    B_k(1) = -(dt_k / (Config.cap * 3600)) * Config.coulomb_efficiency;

    % Voltage prediction
    OCV_pred = interp1(unique_soc_values, unique_ocv_values, SOC_pred, 'linear', 'extrap');
    Vt_pred = OCV_pred + sum(X_est(2:end)) + R0_interp * ik;

elseif strcmp(model_params.model_type, 'DRT')
    % DRT model parameters
    gamma_sorted = model_params.gamma_sorted;
    soc_sorted = model_params.soc_sorted;
    theta_discrete = model_params.theta_discrete;
    tau_discrete = model_params.tau_discrete;
    R0_interp = model_params.R0;

    % Interpolate gamma and calculate R_i and C_i
    gamma_current = interp1(soc_sorted, gamma_sorted, SOC_pred, 'linear', 'extrap');
    gamma_current = gamma_current(:)'; % 1 x num_RC vector
    delta_theta = theta_discrete(2) - theta_discrete(1);
    R_i = gamma_current * delta_theta; % 1 x num_RC vector
    C_i = tau_discrete ./ R_i;         % 1 x num_RC vector

    % State transition matrix A and input matrix B
    exp_term = exp(-dt_k ./ tau_discrete');
    A_k(2:end, 2:end) = diag(exp_term);
    B_k(1) = -(dt_k / (Config.cap * 3600)); % For SOC
    B_k(2:end) = R_i' .* (1 - exp_term');    % For RC voltages

    % Voltage prediction
    OCV_pred = interp1(unique_soc_values, unique_ocv_values, SOC_pred, 'linear', 'extrap');
    Vt_pred = OCV_pred + sum(X_est(2:end)) + R0_interp * ik;

else
    error('Unknown model type');
end

% State prediction
X_pred = A_k * X_est + B_k * ik;

% Covariance prediction
Q_k = diag([Q_params.SOC; repmat(Q_params.V_RC, state_dim - 1, 1)]);
P_pred = A_k * P_est * A_k' + Q_k;

% Observation matrix H
delta_SOC = 1e-5;
OCV_plus = interp1(unique_soc_values, unique_ocv_values, X_pred(1) + delta_SOC, 'linear', 'extrap');
OCV_minus = interp1(unique_soc_values, unique_ocv_values, X_pred(1) - delta_SOC, 'linear', 'extrap');
dOCV_dSOC = (OCV_plus - OCV_minus) / (2 * delta_SOC);

H_k = zeros(1, state_dim);
H_k(1) = dOCV_dSOC;
H_k(2:end) = 1;

% Residual calculation
y_tilde = vk - Vt_pred;

% Kalman gain calculation
S_k = H_k * P_pred * H_k' + R_noise;
K_k = (P_pred * H_k') / S_k;

% State update
X_est = X_pred + K_k * y_tilde;

% Covariance update
P_est = (eye(state_dim) - K_k * H_k) * P_pred;

% Voltage update
OCV_updated = interp1(unique_soc_values, unique_ocv_values, X_est(1), 'linear', 'extrap');

if strcmp(model_params.model_type, 'RC')
    Vt_est = OCV_updated + sum(X_est(2:end)) + model_params.F_R0(X_est(1)) * ik;
elseif strcmp(model_params.model_type, 'DRT')
    Vt_est = OCV_updated + sum(X_est(2:end)) + model_params.R0 * ik;
end

end

