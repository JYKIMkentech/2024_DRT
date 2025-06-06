clc; clear; close all;

%% Seed setting
rng(13);

%% Font size settings
axisFontSize = 14;
titleFontSize = 16;
legendFontSize = 12;
labelFontSize = 14;

%% Define Color Matrix Using lines(9)
c_mat = lines(9);  % Define a color matrix with 9 distinct colors

%% 1. Data load

% ECM parameters (from HPPC test)
load('optimized_params_struct_final_2RC.mat'); % Fields: R0, R1, C1, R2, C2, SOC, avgI, m, Crate

% DRT parameters (gamma and tau values)
load('theta_discrete.mat');
load('gamma_est_all.mat', 'gamma_est_all');  % Note: Removed SOC_mid_all
load('R0_est_all.mat')

tau_discrete = exp(theta_discrete); % tau values

% SOC-OCV lookup table (from C/20 test)
load('soc_ocv.mat', 'soc_ocv'); % [SOC, OCV]
soc_values = soc_ocv(:, 1);     % SOC values % 1083 x 1
ocv_values = soc_ocv(:, 2);     % Corresponding OCV values [V] % 1083 x 1

% Driving data (17 trips)
load('udds_data.mat'); % Struct array 'udds_data' containing fields V, I, t, Time_duration, SOC

Q_batt = 2.7742; % [Ah]
SOC_begin_true = 0.9907;
SOC_begin_cc = 0.9907;
epsilon_percent_span = 0.1;
voltage_noise_percent = 0.01;

[unique_ocv, b] = unique(ocv_values); % unique_ocv : 1029x1
unique_soc = soc_values(b);           % unique_soc : 1029x1  

%% Compute the derivative of OCV with respect to SOC
dOCV_dSOC_values = gradient(unique_ocv) ./ gradient(unique_soc);

windowSize = 10; 
dOCV_dSOC_values_smooth = movmean(dOCV_dSOC_values, windowSize);

%% 2. Kalman filter settings

% Number of RC elements for DRT model
num_RC = length(tau_discrete);

% P
P1_init = [1e-10 0;
            0   1e-10]; % [SOC ; V1] % State covariance
P2_init = [1e-7 0        0;
            0   1e-9   0;
            0   0       1e-69]; % [SOC; V1; V2] % State covariance

P3_init = zeros(1 + num_RC); % Initialize P3_init
P3_init(1,1) = 1e-10;    % Initial covariance for SOC
for i = 2:(1 + num_RC)
    P3_init(i,i) = 1e-10; % Initial covariance for each V_i
end

% Q

Q1 = [1e-6 0;
      0  1e-9];  % [SOC ; V1] % Process covariance

Q2 = [1e-7 0        0;
         0     1e-9    0;
         0      0     1e-9]; % [SOC; V1; V2] % Process covariance

Q3 = zeros(1 + num_RC); % Initialize Q3
Q3(1,1) = 5e-10; % Process noise for SOC
for i = 2:(1 + num_RC)
    Q3(i,i) = 1e-9; % Process noise for each V_i
end

% R , Measurement covariance

R1 = 25e-6;
R2 = 25e-6;
R3 = 25e-3;

%% 3. Extract ECM parameters

num_params = length(optimized_params_struct_final_2RC);
SOC_params = zeros(num_params, 1);
R0_params = zeros(num_params, 1);
R1_params = zeros(num_params, 1);
R2_params = zeros(num_params, 1);
C1_params = zeros(num_params, 1);
C2_params = zeros(num_params, 1);

for i = 1:num_params
    SOC_params(i) = optimized_params_struct_final_2RC(i).SOC;
    R0_params(i) = optimized_params_struct_final_2RC(i).R0;
    R1_params(i) = optimized_params_struct_final_2RC(i).R1;
    R2_params(i) = optimized_params_struct_final_2RC(i).R2;
    C1_params(i) = optimized_params_struct_final_2RC(i).C1;
    C2_params(i) = optimized_params_struct_final_2RC(i).C2;
end

%% 4. Apply Kalman filter to all trips

num_trips = length(udds_data);

% Initialize cell arrays to store results for each trip
True_SOC_all = cell(num_trips, 1);   
CC_SOC_all = cell(num_trips, 1);
SOC_est_1RC_all = cell(num_trips, 1);
SOC_est_2RC_all = cell(num_trips, 1);
SOC_est_DRT_all = cell(num_trips, 1);
t_all = cell(num_trips, 1);
I_all = cell(num_trips, 1);
V_all = cell(num_trips, 1);

% Initialize cell arrays to store SOC errors for each trip
SOC_error_CC_all = cell(num_trips,1);
SOC_error_1RC_all = cell(num_trips,1);
SOC_error_2RC_all = cell(num_trips,1);
SOC_error_DRT_all = cell(num_trips,1);

% Initialize estimates for all models
% These will be updated after each trip
SOC_estimate_DRT = SOC_begin_cc;
V_estimate_DRT = zeros(num_RC,1); % V_i initial values for DRT

SOC_estimate_1RC = SOC_begin_cc;
V1_est_1RC = 0; % V1 initial value for 1-RC

SOC_estimate_2RC = SOC_begin_cc;
V1_est_2RC = 0; % V1 initial value for 2-RC
V2_est_2RC = 0; % V2 initial value for 2-RC

% Initialize error covariances for all models
P_estimate_DRT = P3_init;
P_estimate_1RC = P1_init;
P_estimate_2RC = P2_init;

% For concatenating SOC estimates over all trips
% We will concatenate after processing all trips
t_total = [];
True_SOC_total = [];
CC_SOC_total = [];
SOC_est_1RC_total = [];
SOC_est_2RC_total = [];
SOC_est_DRT_total = [];
I_total = [];
V_total = [];
SOC_error_CC_total = [];
SOC_error_1RC_total = [];
SOC_error_2RC_total = [];
SOC_error_DRT_total = [];

time_offset = 0; % To adjust time for concatenation

for s = 1 : num_trips-1 % For each trip
    fprintf('Processing Trip %d/%d...\n', s, num_trips-1);

    I = udds_data(s).I;
    V = udds_data(s).V;
    t = udds_data(s).t + time_offset; % Adjust time for concatenation
    dt = [t(1); diff(t)];
    dt(1) = dt(2);
    Time_duration = udds_data(s).Time_duration; % All trips start continuously

    [noisy_I] = Markov(I,epsilon_percent_span); % Add Markov noise to current 
    noisy_V = V + voltage_noise_percent * V .* randn(size(V)); % Add Gaussian noise to voltage 

    % True SOC (without noise)
    True_SOC = SOC_begin_true + cumtrapz(t - time_offset,I)/(3600 * Q_batt);
    % CC SOC (with noisy current)
    CC_SOC = SOC_begin_cc + cumtrapz(t - time_offset,noisy_I)/(3600 * Q_batt);

    True_SOC_all{s} = True_SOC;
    CC_SOC_all{s} = CC_SOC;
    t_all{s} = t;
    I_all{s} = I;
    V_all{s} = V;

    % Update SOC_begin for the next trip
    SOC_begin_true = True_SOC(end);
    SOC_begin_cc = CC_SOC(end);

    %% DRT

    gamma = gamma_est_all(s,:); % 1x201
    delta_theta = theta_discrete(2) - theta_discrete(1); % 0.0476
    R_i = gamma * delta_theta; % 1x201
    C_i = tau_discrete' ./ R_i; % 1x201

    SOC_est_DRT = zeros(length(t),1);
    V_DRT_est = zeros(length(t), num_RC); % Store V_i for each time step

    for k = 1:length(t) % Prediction and correction for each time step

        R0 = interp1(SOC_params, R0_params, SOC_estimate_DRT, 'linear', 'extrap');

        % Predict step
        if k == 1
            % For the first time step of each trip, use estimates from the previous trip
            if s == 1
                % For the very first trip
                V_pred = zeros(num_RC,1);
                for i = 1:num_RC
                    V_pred(i) = noisy_I(k) * R_i(i) * (1 - exp(-dt(k) / (R_i(i) * C_i(i))));
                end
            else
                V_pred = V_estimate_DRT; % Use the last estimates from the previous trip
            end
        else
            % Predict V_i
            V_pred = zeros(num_RC,1);
            for i = 1:num_RC
                V_pred(i) = V_estimate_DRT(i) * exp(-dt(k) / (R_i(i) * C_i(i))) + noisy_I(k) * R_i(i) * (1 - exp(-dt(k) / (R_i(i) * C_i(i))));
            end
        end

        % Predict SOC
        SOC_pred = SOC_estimate_DRT + (dt(k) / (Q_batt * 3600)) * noisy_I(k);
        x_pred = [SOC_pred; V_pred];

        % Predict the error covariance
        A = eye(1 + num_RC);
        A(1,1) = 1; % SOC remains unchanged
        for i = 1:num_RC
            A(i+1,i+1) = exp(-dt(k) / (R_i(i) * C_i(i)));
        end
        P_pred = A * P_estimate_DRT * A' + Q3;

        % Compute OCV_pred and dOCV_dSOC
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred, 'linear', 'extrap');

        % Measurement matrix H
        H = zeros(1, 1 + num_RC);
        H(1) = dOCV_dSOC;
        H(2:end) = 1;

        % Compute the predicted voltage
        V_pred_total = OCV_pred + sum(V_pred) + R0 * noisy_I(k);

        % Compute the Kalman gain
        S_k = H * P_pred * H' + R3; % Measurement noise covariance
        K = (P_pred * H') / S_k;

        % Update the estimate
        z = noisy_V(k); % Measurement
        x_estimate = x_pred + K * (z - V_pred_total);

        % Update the error covariance
        P_estimate_DRT = (eye(1 + num_RC) - K * H) * P_pred;

        % Store the estimates
        SOC_est_DRT(k) = x_estimate(1);
        V_estimate_DRT = x_estimate(2:end);
        V_DRT_est(k, :) = V_estimate_DRT';

        % Update the estimates for next iteration
        SOC_estimate_DRT = x_estimate(1);
    end

    SOC_est_DRT_all{s} = SOC_est_DRT; 

    %% 1-RC

    SOC_est_1RC = zeros(length(t), 1);
    V1_est_1RC = zeros(length(t), 1);

    for k = 1:length(t)

        % Compute R0, R1, C1 at SOC_estimate_1RC
        R0 = interp1(SOC_params, R0_params, SOC_estimate_1RC, 'linear', 'extrap');
        R1 = interp1(SOC_params, R1_params, SOC_estimate_1RC, 'linear', 'extrap');
        C1 = interp1(SOC_params, C1_params, SOC_estimate_1RC, 'linear', 'extrap');

        % Predict step
        if k == 1
            if s == 1
                V1_pred = noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
            else
                V1_pred = V1_estimate_1RC; % Use the last estimate from the previous trip
            end
        else
            % Predict V1
            V1_pred = V1_estimate_1RC * exp(-dt(k) / (R1 * C1)) + noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
        end

        % Predict SOC
        SOC_pred = SOC_estimate_1RC + (dt(k) / (Q_batt * 3600)) * noisy_I(k);

        % Form the predicted state vector
        x_pred = [SOC_pred; V1_pred];

        % Predict the error covariance
        A = [1 0;
             0 exp(-dt(k) / (R1 * C1))];
        P_pred = A * P_estimate_1RC * A' + Q1;

        % Compute OCV_pred and dOCV_dSOC
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred, 'linear', 'extrap');

        % Measurement matrix H
        H = [dOCV_dSOC, 1];

        % Compute the predicted voltage
        V_pred_total = OCV_pred + V1_pred + R0 * noisy_I(k);

        % Compute the Kalman gain
        S_k = H * P_pred * H' + R1; % Measurement noise covariance
        K = (P_pred * H') / S_k;

        % Update the estimate
        z = noisy_V(k); % Measurement
        x_estimate = x_pred + K * (z - V_pred_total);

        % Update the error covariance
        P_estimate_1RC = (eye(2) - K * H) * P_pred;

        % Store the estimates
        SOC_est_1RC(k) = x_estimate(1);
        V1_est_1RC(k) = x_estimate(2);

        % Update the estimates for next iteration
        SOC_estimate_1RC = x_estimate(1);
        V1_estimate_1RC = x_estimate(2);
    end

    SOC_est_1RC_all{s} = SOC_est_1RC;

    %% 2-RC

    SOC_est_2RC = zeros(length(t),1);
    V1_est_2RC = zeros(length(t),1);
    V2_est_2RC = zeros(length(t),1);

    for k = 1:length(t)
        % Compute R0, R1, C1, R2, C2 at SOC_estimate_2RC
        R0 = interp1(SOC_params, R0_params, SOC_estimate_2RC, 'linear', 'extrap');
        R1 = interp1(SOC_params, R1_params, SOC_estimate_2RC, 'linear', 'extrap');
        C1 = interp1(SOC_params, C1_params, SOC_estimate_2RC, 'linear', 'extrap');
        R2 = interp1(SOC_params, R2_params, SOC_estimate_2RC, 'linear', 'extrap');
        C2 = interp1(SOC_params, C2_params, SOC_estimate_2RC, 'linear', 'extrap');

        % Predict step
        if k == 1
            if s == 1
                V1_pred = noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
                V2_pred = noisy_I(k) * R2 * (1 - exp(-dt(k) / (R2 * C2)));
            else
                V1_pred = V1_estimate_2RC; % Use the last estimate from the previous trip
                V2_pred = V2_estimate_2RC; % Use the last estimate from the previous trip
            end
        else
            % Predict V1 and V2
            V1_pred = V1_estimate_2RC * exp(-dt(k) / (R1 * C1)) + noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
            V2_pred = V2_estimate_2RC * exp(-dt(k) / (R2 * C2)) + noisy_I(k) * R2 * (1 - exp(-dt(k) / (R2 * C2)));
        end

        % Predict SOC
        SOC_pred = SOC_estimate_2RC + (dt(k) / (Q_batt * 3600)) * noisy_I(k);

        % Form the predicted state vector
        x_pred = [SOC_pred; V1_pred; V2_pred];

        % Predict the error covariance
        A = [1 0 0;
             0 exp(-dt(k) / (R1 * C1)) 0;
             0 0 exp(-dt(k) / (R2 * C2))];
        P_pred = A * P_estimate_2RC * A' + Q2;

        % Compute OCV_pred and dOCV_dSOC
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred, 'linear', 'extrap');

        % Measurement matrix H
        H = [dOCV_dSOC, 1, 1];

        % Compute the predicted voltage
        V_pred_total = OCV_pred + V1_pred + V2_pred + R0 * noisy_I(k);

        % Compute the Kalman gain
        S_k = H * P_pred * H' + R2; % Measurement noise covariance
        K = (P_pred * H') / S_k;

        % Update the estimate
        z = noisy_V(k); % Measurement
        x_estimate = x_pred + K * (z - V_pred_total);

        % Update the error covariance
        P_estimate_2RC = (eye(3) - K * H) * P_pred;

        % Store the estimates
        SOC_est_2RC(k) = x_estimate(1);
        V1_est_2RC(k) = x_estimate(2);
        V2_est_2RC(k) = x_estimate(3);

        % Update the estimates for next iteration
        SOC_estimate_2RC = x_estimate(1);
        V1_estimate_2RC = x_estimate(2);
        V2_estimate_2RC = x_estimate(3);
    end

    SOC_est_2RC_all{s} = SOC_est_2RC;

    %% Calculate SOC errors for this trip
    SOC_error_CC = CC_SOC - True_SOC;
    SOC_error_1RC = SOC_est_1RC - True_SOC;
    SOC_error_2RC = SOC_est_2RC - True_SOC;
    SOC_error_DRT = SOC_est_DRT - True_SOC;

    % Store SOC errors
    SOC_error_CC_all{s} = SOC_error_CC;
    SOC_error_1RC_all{s} = SOC_error_1RC;
    SOC_error_2RC_all{s} = SOC_error_2RC;
    SOC_error_DRT_all{s} = SOC_error_DRT;

    %% Plot SOC estimates for individual trip
    figure;
    plot(t, True_SOC, '--', 'Color', c_mat(1, :), 'LineWidth', 1.5);
    hold on;
    plot(t, CC_SOC, 'Color', c_mat(2, :), 'LineWidth', 1.5);
    plot(t, SOC_est_1RC, '--', 'Color', c_mat(3, :), 'LineWidth', 1.5);
    plot(t, SOC_est_2RC, '--', 'Color', c_mat(4, :), 'LineWidth', 1.5);
    plot(t, SOC_est_DRT, '--', 'Color', c_mat(5, :), 'LineWidth', 1.5);

    xlabel('Time [s]', 'FontSize', labelFontSize);
    ylabel('SOC', 'FontSize', labelFontSize);
    legend('True SOC', 'Coulomb Counting SOC', 'Estimated SOC (1-RC)', 'Estimated SOC (2-RC)', 'Estimated SOC (DRT)', 'FontSize', legendFontSize);
    title(['SOC Estimation for Trip ', num2str(s)], 'FontSize', titleFontSize);
    grid on;
    set(gca, 'FontSize', axisFontSize);
    hold off;

    %% Update time offset
    time_offset = t(end);

end

%% Concatenate data for total plots
t_total = cell2mat(t_all);
True_SOC_total = cell2mat(True_SOC_all);
CC_SOC_total = cell2mat(CC_SOC_all);
SOC_est_1RC_total = cell2mat(SOC_est_1RC_all);
SOC_est_2RC_total = cell2mat(SOC_est_2RC_all);
SOC_est_DRT_total = cell2mat(SOC_est_DRT_all);
I_total = cell2mat(I_all);
V_total = cell2mat(V_all);
SOC_error_CC_total = cell2mat(SOC_error_CC_all);
SOC_error_1RC_total = cell2mat(SOC_error_1RC_all);
SOC_error_2RC_total = cell2mat(SOC_error_2RC_all);
SOC_error_DRT_total = cell2mat(SOC_error_DRT_all);

%% Calculate error metrics over all trips

% Coulomb Counting
ME_CC = mean(SOC_error_CC_total);
MAE_CC = mean(abs(SOC_error_CC_total));
RMSE_CC = sqrt(mean(SOC_error_CC_total.^2));
Max_Error_CC = max(abs(SOC_error_CC_total));

% 1RC Model
ME_1RC = mean(SOC_error_1RC_total);
MAE_1RC = mean(abs(SOC_error_1RC_total));
RMSE_1RC = sqrt(mean(SOC_error_1RC_total.^2));
Max_Error_1RC = max(abs(SOC_error_1RC_total));

% 2RC Model
ME_2RC = mean(SOC_error_2RC_total);
MAE_2RC = mean(abs(SOC_error_2RC_total));
RMSE_2RC = sqrt(mean(SOC_error_2RC_total.^2));
Max_Error_2RC = max(abs(SOC_error_2RC_total));

% DRT Model
ME_DRT = mean(SOC_error_DRT_total);
MAE_DRT = mean(abs(SOC_error_DRT_total));
RMSE_DRT = sqrt(mean(SOC_error_DRT_total.^2));
Max_Error_DRT = max(abs(SOC_error_DRT_total));

%% Combine results into a table
Error_Metrics = {'Mean Error (ME)'; 'Mean Absolute Error (MAE)'; 'Root Mean Square Error (RMSE)'; 'Maximum Error (Max Error)'};
Coulomb_Counting = [ME_CC; MAE_CC; RMSE_CC; Max_Error_CC];
Model_1RC = [ME_1RC; MAE_1RC; RMSE_1RC; Max_Error_1RC];
Model_2RC = [ME_2RC; MAE_2RC; RMSE_2RC; Max_Error_2RC];
Model_DRT = [ME_DRT; MAE_DRT; RMSE_DRT; Max_Error_DRT];

Results_Table = table(Error_Metrics, Coulomb_Counting, Model_1RC, Model_2RC, Model_DRT, ...
    'VariableNames', {'Error_Metric', 'Coulomb_Counting', '1RC_Model', '2RC_Model', 'DRT_Model'});

%% Display the table in a formatted way
fprintf('\nSOC Estimation Error Metrics Over All Trips:\n\n');
fprintf('%-25s %-20s %-20s %-20s %-20s\n', 'Error Metric', 'Coulomb Counting', '1RC Model', '2RC Model', 'DRT Model');
fprintf('-----------------------------------------------------------------------------------------------\n');
fprintf('%-25s %-20.6e %-20.6e %-20.6e %-20.6e\n', 'Mean Error (ME)', ME_CC, ME_1RC, ME_2RC, ME_DRT);
fprintf('%-25s %-20.6e %-20.6e %-20.6e %-20.6e\n', 'Mean Absolute Error (MAE)', MAE_CC, MAE_1RC, MAE_2RC, MAE_DRT);
fprintf('%-25s %-20.6e %-20.6e %-20.6e %-20.6e\n', 'RMSE', RMSE_CC, RMSE_1RC, RMSE_2RC, RMSE_DRT);
fprintf('%-25s %-20.6e %-20.6e %-20.6e %-20.6e\n', 'Maximum Error', Max_Error_CC, Max_Error_1RC, Max_Error_2RC, Max_Error_DRT);

%% Optionally, display the table in MATLAB's variable window
disp(' ');
disp('SOC Estimation Error Metrics Over All Trips:');
disp(Results_Table);

%% Plot combined SOC estimates over all trips
figure;
plot(t_total, True_SOC_total, '--', 'Color', c_mat(1, :), 'LineWidth', 1.5);
hold on;
plot(t_total, CC_SOC_total, 'Color', c_mat(2, :), 'LineWidth', 1.5);
plot(t_total, SOC_est_1RC_total, '-', 'Color', c_mat(3, :), 'LineWidth', 1.5);
plot(t_total, SOC_est_2RC_total, '-', 'Color', c_mat(4, :), 'LineWidth', 1.5);
plot(t_total, SOC_est_DRT_total, '-', 'Color', c_mat(5, :), 'LineWidth', 1.5);

xlabel('Time [s]', 'FontSize', labelFontSize);
ylabel('SOC', 'FontSize', labelFontSize);
legend('True SOC', 'Coulomb Counting SOC', 'Estimated SOC (1-RC)', 'Estimated SOC (2-RC)', 'Estimated SOC (DRT)', 'FontSize', legendFontSize);
title('SOC Estimation Over All Trips', 'FontSize', titleFontSize);
grid on;
set(gca, 'FontSize', axisFontSize);
hold off;

%% Plot SOC estimation errors over all trips
figure;
plot(t_total, SOC_error_CC_total, 'Color', c_mat(2, :), 'LineWidth', 1.5);
hold on;
plot(t_total, SOC_error_1RC_total, '-', 'Color', c_mat(3, :), 'LineWidth', 1.5);
plot(t_total, SOC_error_2RC_total, '-', 'Color', c_mat(4, :), 'LineWidth', 1.5);
plot(t_total, SOC_error_DRT_total, '-', 'Color', c_mat(5, :), 'LineWidth', 1.5);

xlabel('Time [s]', 'FontSize', labelFontSize);
ylabel('SOC Error', 'FontSize', labelFontSize);
legend('CC SOC Error', 'Estimated SOC Error (1-RC)', 'Estimated SOC Error (2-RC)', 'Estimated SOC Error (DRT)', 'FontSize', legendFontSize);
title('SOC Estimation Error Over All Trips', 'FontSize', titleFontSize);
grid on;
set(gca, 'FontSize', axisFontSize);
hold off;

%% Function for adding Markov noise
function [noisy_I] = Markov(I, epsilon_percent_span)

    % Define noise parameters
    sigma_percent = 0.001;      % Standard deviation in percentage (adjust as needed)

    N = 51; % Number of states
    epsilon_vector = linspace(-epsilon_percent_span/2, epsilon_percent_span/2, N); % From -noise_percent to +noise_percent
    sigma = sigma_percent; % Standard deviation

    % Initialize transition probability matrix P
    P = zeros(N);
    for i = 1:N
        probabilities = normpdf(epsilon_vector, epsilon_vector(i), sigma);
        P(i, :) = probabilities / sum(probabilities); % Normalize to sum to 1
    end

    % Initialize state tracking
    initial_state = 3; 
    current_state = initial_state;

    % Initialize output variables
    noisy_I = zeros(size(I));
    states = zeros(size(I)); % Vector to store states
    epsilon = zeros(size(I));

    % Generate noisy current and track states
    for k = 1:length(I)
        epsilon(k) = epsilon_vector(current_state);
        noisy_I(k) = I(k) + abs(I(k)) * epsilon(k); % Apply the epsilon percentage

        states(k) = current_state; % Store the current state

        % Transition to the next state based on probabilities
        current_state = randsample(1:N, 1, true, P(current_state, :));
    end

end
