function [X_est, P_est, Vt_est] = kalman_filter(...
    X_prev, P_prev, ik, vk, dt_k, Config, ...
    unique_soc_values, unique_ocv_values, F_R0, F_R, F_C, ...
    Q_params, R_noise, num_RC)

% Unpack previous state estimate
X_est = X_prev;
P_est = P_prev;

% State dimension
state_dim = 1 + num_RC;

% SOC prediction (Coulomb Counting)
SOC_pred = X_est(1) + (dt_k / (Config.cap * 3600)) * Config.coulomb_efficiency * ik;
SOC_pred = max(0, min(1, SOC_pred)); % Limit SOC between 0 and 1

% ECM parameter interpolation
R0_interp = F_R0(SOC_pred);
R_interp = F_R(SOC_pred);
C_interp = F_C(SOC_pred);

% State transition matrix A and input matrix B
A_k = eye(state_dim);
for i = 1:num_RC
    A_k(1+i, 1+i) = exp(-dt_k / (R_interp(i) * C_interp(i)));
end

B_k = zeros(state_dim, 1);
B_k(1) = -(dt_k / (Config.cap * 3600)) * Config.coulomb_efficiency;
for i = 1:num_RC
    B_k(1+i) = R_interp(i) * (1 - exp(-dt_k / (R_interp(i) * C_interp(i))));
end

% State prediction
X_pred = A_k * X_est + B_k * ik;

% Covariance prediction
Q_k = diag([Q_params.SOC; repmat(Q_params.V_RC, num_RC, 1)]);
P_pred = A_k * P_est * A_k' + Q_k;

% Voltage prediction
OCV_pred = interp1(unique_soc_values, unique_ocv_values, X_pred(1), 'linear', 'extrap');
Vt_pred = OCV_pred + sum(X_pred(2:end)) + R0_interp * ik;

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
Vt_est = OCV_updated + sum(X_est(2:end)) + F_R0(X_est(1)) * ik;

end
