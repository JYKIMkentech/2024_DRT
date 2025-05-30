clc; clear; close all;

%% Seed Setting
rng(13);

%% Font Size Settings
axisFontSize = 14;
titleFontSize = 16;
legendFontSize = 12;
labelFontSize = 14;

%% Define Color Matrix
c_mat = lines(9);  

%% 1. Data Load

% ECM parameters
load('optimized_params_struct_final_2RC.mat'); % Fields: R0, R1, C1, R2, C2, SOC, avgI, m, Crate

% DRT parameters (gamma and tau values)
load('theta_discrete.mat');
load('gamma_est_all.mat', 'gamma_est_all');  % Note: Removed SOC_mid_all
load('R0_est_all.mat')

tau_discrete = exp(theta_discrete); % tau values

% SOC-OCV lookup table (from C/20 test)
load('soc_ocv.mat', 'soc_ocv'); % [SOC, OCV]
soc_values = soc_ocv(:, 1);     % SOC values
ocv_values = soc_ocv(:, 2);     % Corresponding OCV values [V]

load('udds_data.mat'); % Struct array 'udds_data' containing fields V, I, t, Time_duration, SOC

Q_batt = 2.7742 ; % [Ah]
SOC_begin_true = 0.9907;
SOC_begin_cc = 0.9907;
epsilon_percent_span = 0.2;
voltage_noise_percent = 0.01;

[unique_ocv, b] = unique(ocv_values);
unique_soc = soc_values(b);

% Compute the derivative of OCV with respect to SOC
dOCV_dSOC_values = gradient(unique_ocv) ./ gradient(unique_soc);
windowSize = 10; 
dOCV_dSOC_values_smooth = movmean(dOCV_dSOC_values, windowSize);


%% 2. Kalman Filter Settings

%% 1204 covariance 설정

Voltage_cov = logspace(-15,-20,6);
%SOC_cov = [1e-13, 1e-14];

soc_cov = 1e-15;
V_cov = Voltage_cov(2);

% Number of RC elements for DRT model
num_RC = length(tau_discrete);

% P
Pcov1_init = [soc_cov 0;  
            0   V_cov ]; 
Pcov2_init = [ 1.4 * soc_cov 0        0;
            0   V_cov/4  0;
            0   0      V_cov/4]; % [SOC; V1; V2] % State covariance

Pcov3_init = zeros(1 + num_RC); % Initialize P3_init
Pcov3_init(1,1) = 20 * soc_cov;    % Initial covariance for SOC
for i = 2:(1 + num_RC)
    Pcov3_init(i,i) = V_cov/201^2; % Initial covariance for each V_i
end

% Q
Qcov1 = [soc_cov 0;
      0  V_cov ];  % [SOC ; V1] % Process covariance

Qcov2 = [ 1.4 * soc_cov    0        0;
             0     V_cov/4     0;
             0      0     V_cov/4 ]; % [SOC; V1; V2] % Process covariance

Qcov3 = zeros(1 + num_RC); % Initialize Q3
Qcov3(1,1) =  20 * soc_cov; % Process noise for SOC
for i = 2:(1 + num_RC)
    Qcov3(i,i) = V_cov/201^2;% Process noise for each V_i
end

% R , Measurement covariance
Rcov1 = 5.25e-6;
Rcov2 = 5.25e-6;
Rcov3 = 5.25e-6;

%%
% Number of RC elements for DRT model
% num_RC = length(tau_discrete);
% 
% % P
% Pcov1_init = [2e-14 0;  % 1e-13 to 1e-14 
%             0   1e-10 ]; % [SOC ; V1] % State covariance % 1e-4 to 1e-10 
% Pcov2_init = [3e-14 0        0;
%             0   1e-10/2   0;
%             0   0      1e-10/2 ]; % [SOC; V1; V2] % State covariance
% 
% Pcov3_init = zeros(1 + num_RC); % Initialize P3_init
% Pcov3_init(1,1) = 5e-13;    % Initial covariance for SOC
% for i = 2:(1 + num_RC)
%     Pcov3_init(i,i) = 5e-10/201; % Initial covariance for each V_i
% end
% 
% % Q
% Qcov1 = [2e-14 0;
%       0  1e-14 ];  % [SOC ; V1] % Process covariance
% 
% Qcov2 = [3e-14 0        0;
%              0     1e-10/2      0;
%              0      0     1e-10/2 ]; % [SOC; V1; V2] % Process covariance
% 
% Qcov3 = zeros(1 + num_RC); % Initialize Q3
% Qcov3(1,1) = 5e-13; % Process noise for SOC
% for i = 2:(1 + num_RC)
%     Qcov3(i,i) = 5e-10/201  ;% Process noise for each V_i
% end
% 
% % R , Measurement covariance
% Rcov1 = 5.25e-6;
% Rcov2 = 5.25e-6;
% Rcov3 = 5.25e-6;



%% 3. Extract ECM Parameters
SOC_params = vertcat(optimized_params_struct_final_2RC.SOC);
R0_params = vertcat(optimized_params_struct_final_2RC.R0);
R1_params = vertcat(optimized_params_struct_final_2RC.R1);
C1_params = vertcat(optimized_params_struct_final_2RC.C1);
R2_params = vertcat(optimized_params_struct_final_2RC.R2);
C2_params = vertcat(optimized_params_struct_final_2RC.C2);

%% 4. Kalman Filter

num_trips = length(udds_data);

% Initialize SOC,V1,P for 1RC model
initial_SOC_true = SOC_begin_true;
initial_SOC_cc = SOC_begin_cc;
initial_P_estimate_1RC = Pcov1_init;
initial_SOC_estimate_1RC = initial_SOC_cc;
initial_V1_estimate_1RC = 0;

% Initialize data over all trips for 1RC
t_all = [];
True_SOC_all = [];
CC_SOC_all = [];
x_pred_1RC_all_trips = [];
x_estimate_1RC_all_trips = [];
KG_1RC_all_trips = [];
residual_1RC_all_trips = [];
I_all = [];
noisy_I_all = [];

% Initialize SOC,V1,V2,P for 2RC model
initial_P_estimate_2RC = Pcov2_init;
initial_SOC_estimate_2RC = initial_SOC_cc;
initial_V1_estimate_2RC = 0;
initial_V2_estimate_2RC = 0;

% Initialize data over all trips for 2RC
x_pred_2RC_all_trips = [];
x_estimate_2RC_all_trips = [];
KG_2RC_all_trips = [];
residual_2RC_all_trips = [];

% Initialize SOC,V_DRT,P for DRT model
initial_P_estimate_DRT = Pcov3_init;
initial_SOC_estimate_DRT = initial_SOC_cc;
initial_V_estimate_DRT = zeros(num_RC, 1);

% Initialize data over all trips for DRT
x_pred_DRT_all_trips = [];
x_estimate_DRT_all_trips = [];
KG_DRT_all_trips = [];
residual_DRT_all_trips = [];

% Initialize previous trip's end time
previous_trip_end_time = 0;

for s = 1:num_trips-1 % For each trip
    fprintf('Processing Trip %d/%d...\n', s, num_trips);
    
    % Use Time_duration as time vector
    t = udds_data(s).Time_duration;
    I = udds_data(s).I;
    V = udds_data(s).V;

    % Calculate dt
    if s == 1
        dt = [t(1); diff(t)];      % First trip: prepend t(1)
        dt(1) = dt(2);             % Set dt(1) equal to dt(2)
    else
        dt = [t(1) - previous_trip_end_time; diff(t)]; % For other trips
    end

    fprintf('Trip %d, dt(1): %f\n', s, dt(1));

    [noisy_I] = Markov(I, epsilon_percent_span); % Current: Markov noise
    noisy_V = V + voltage_noise_percent * V .* randn(size(V)); % Voltage: Gaussian noise

    % Compute True SOC and CC SOC
    True_SOC = initial_SOC_true + cumtrapz(t - t(1), I)/(3600 * Q_batt);
    CC_SOC = initial_SOC_cc + cumtrapz(t - t(1), noisy_I)/(3600 * Q_batt);

    % 1-RC 

    SOC_est_1RC = zeros(length(t), 1);
    V1_est_1RC = zeros(length(t), 1);   

    SOC_estimate_1RC = initial_SOC_estimate_1RC;
    P_estimate_1RC = initial_P_estimate_1RC;
    V1_estimate_1RC = initial_V1_estimate_1RC;

    % Kalman filter variables for 1RC
    x_pred_1RC_all = zeros(length(t), 2);     % Predicted states
    KG_1RC_all = zeros(length(t), 2);         % Kalman gains
    residual_1RC_all = zeros(length(t), 1);   % Residuals
    x_estimate_1RC_all = zeros(length(t), 2); % Updated states

    % 2-RC

    SOC_est_2RC = zeros(length(t), 1);
    V1_est_2RC = zeros(length(t), 1);
    V2_est_2RC = zeros(length(t), 1);

    SOC_estimate_2RC = initial_SOC_estimate_2RC;
    V1_estimate_2RC = initial_V1_estimate_2RC;
    V2_estimate_2RC = initial_V2_estimate_2RC;
    P_estimate_2RC = initial_P_estimate_2RC;

    % Kalman filter variables for 2RC
    x_pred_2RC_all = zeros(length(t), 3);     % Predicted states
    x_estimate_2RC_all = zeros(length(t), 3); % Updated states
    KG_2RC_all = zeros(length(t), 3);         % Kalman gains
    residual_2RC_all = zeros(length(t), 1);   % Residuals

    % DRT

    gamma = gamma_est_all(s,:); % 1x201
    delta_theta = theta_discrete(2) - theta_discrete(1); % 0.0476
    R_i = gamma * delta_theta; % 1x201
    C_i = tau_discrete' ./ R_i; % 201x1

    SOC_est_DRT = zeros(length(t),1);
    V_est_DRT = zeros(length(t), num_RC);

    SOC_estimate_DRT = initial_SOC_estimate_DRT;
    V_estimate_DRT = initial_V_estimate_DRT; % 201x1
    P_estimate_DRT = initial_P_estimate_DRT;

    % Kalman filter variables for DRT
    x_pred_DRT_all = zeros(length(t), 1 + num_RC); % [SOC ; V_DRT(1) ; V_DRT(2) ; ... ; V_DRT(201)]
    x_estimate_DRT_all = zeros(length(t), 1 + num_RC); % [SOC ; V_DRT(1) ; V_DRT(2) ; ... ; V_DRT(201)]
    KG_DRT_all = zeros(length(t), 1 + num_RC); % [KG_SOC , KG_V_DRT(1), ..., KG_V_DRT(201)]
    residual_DRT_all = zeros(length(t), 1); % Residuals

    for k = 1:length(t) % For each time step

        %% 1RC

        % Interpolate R0, R1, C1 based on SOC for 1RC
        R0 = interp1(SOC_params, R0_params, SOC_estimate_1RC, 'linear', 'extrap');
        R1 = interp1(SOC_params, R1_params, SOC_estimate_1RC, 'linear', 'extrap');
        C1 = interp1(SOC_params, C1_params, SOC_estimate_1RC, 'linear', 'extrap');

        %% Predict Step for 1RC
        if k == 1
            if s == 1
                V1_pred = noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
            else
                V1_pred = V1_estimate_1RC * exp(-dt(k) / (R1 * C1)) + noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
            end
        else 
            V1_pred = V1_estimate_1RC * exp(-dt(k) / (R1 * C1)) + noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
        end

        % Predict SOC for 1RC
        SOC_pred_1RC = SOC_estimate_1RC + (dt(k) / (Q_batt * 3600)) * noisy_I(k);

        % Form the predicted state vector for 1RC
        x_pred = [SOC_pred_1RC; V1_pred];

        % Store the predicted state vector for 1RC
        x_pred_1RC_all(k, :) = x_pred';

        % Predict the error covariance for 1RC
        A = [1 0;
             0 exp(-dt(k) / (R1 * C1))];
        P_pred_1RC = A * P_estimate_1RC * A' + Qcov1;

        % Compute OCV_pred and dOCV_dSOC for 1RC
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred_1RC, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred_1RC, 'linear', 'extrap');

        % Measurement matrix H for 1RC
        H = [dOCV_dSOC, 1];

        % Compute the predicted voltage for 1RC
        V_pred_total = OCV_pred + V1_pred + R0 * noisy_I(k);

        % Compute the Kalman gain for 1RC
        S_k = H * P_pred_1RC * H' + Rcov1;
        KG = (P_pred_1RC * H') / S_k;

        % Store the Kalman gain for 1RC
        KG_1RC_all(k, :) = KG';

        %% Update Step for 1RC

        z = noisy_V(k);
        residual = z - V_pred_total;

        % Store the residual for 1RC
        residual_1RC_all(k) = residual;

        % Update the estimate for 1RC
        x_estimate = x_pred + KG * residual;

        SOC_estimate_1RC = x_estimate(1);
        V1_estimate_1RC = x_estimate(2);

        % Store the updated state vector for 1RC
        x_estimate_1RC_all(k, :) = x_estimate';

        % Update the error covariance for 1RC
        P_estimate_1RC = (eye(2) - KG * H) * P_pred_1RC;

        SOC_est_1RC(k) = x_estimate(1);
        V1_est_1RC(k) = x_estimate(2);


        %% 2RC

        % Interpolate R0, R1, C1, R2, C2 based on SOC for 2RC
        R0 = interp1(SOC_params, R0_params, SOC_estimate_2RC, 'linear', 'extrap');
        R1 = interp1(SOC_params, R1_params, SOC_estimate_2RC, 'linear', 'extrap');
        C1 = interp1(SOC_params, C1_params, SOC_estimate_2RC, 'linear', 'extrap');
        R2 = interp1(SOC_params, R2_params, SOC_estimate_2RC, 'linear', 'extrap');
        C2 = interp1(SOC_params, C2_params, SOC_estimate_2RC, 'linear', 'extrap');

        %% Predict Step for 2RC
        if k == 1
            if s == 1
                V1_pred = noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
                V2_pred = noisy_I(k) * R2 * (1 - exp(-dt(k) / (R2 * C2)));
            else
                V1_pred = V1_estimate_2RC;
                V2_pred = V2_estimate_2RC;
            end
        else
            V1_pred = V1_estimate_2RC * exp(-dt(k) / (R1 * C1)) + noisy_I(k) * R1 * (1 - exp(-dt(k) / (R1 * C1)));
            V2_pred = V2_estimate_2RC * exp(-dt(k) / (R2 * C2)) + noisy_I(k) * R2 * (1 - exp(-dt(k) / (R2 * C2)));
        end

        % Predict SOC for 2RC
        SOC_pred_2RC = SOC_estimate_2RC + (dt(k) / (Q_batt * 3600)) * noisy_I(k);

        % Form the predicted state vector for 2RC
        x_pred = [SOC_pred_2RC; V1_pred; V2_pred];

        % Store the predicted state vector for 2RC
        x_pred_2RC_all(k, :) = x_pred';

        % Predict the error covariance for 2RC
        A = [1 0 0;
             0 exp(-dt(k) / (R1 * C1)) 0;
             0 0 exp(-dt(k) / (R2 * C2))];
        P_pred_2RC = A * P_estimate_2RC * A' + Qcov2;

        % Compute OCV_pred and dOCV_dSOC for 2RC
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred_2RC, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred_2RC, 'linear', 'extrap');

        % Measurement matrix H for 2RC
        H = [dOCV_dSOC, 1, 1];

        % Compute the predicted voltage for 2RC
        V_pred_total = OCV_pred + V1_pred + V2_pred + R0 * noisy_I(k);

        % Compute the Kalman gain for 2RC
        S_k = H * P_pred_2RC * H' + Rcov2;
        KG = (P_pred_2RC * H') / S_k;

        % Store the Kalman gain for 2RC
        KG_2RC_all(k, :) = KG';

        %% Update Step for 2RC

        z = noisy_V(k);
        residual = z - V_pred_total;

        % Store the residual for 2RC
        residual_2RC_all(k) = residual;

        % Update the estimate for 2RC
        x_estimate = x_pred + KG * residual;

        SOC_estimate_2RC = x_estimate(1);
        V1_estimate_2RC = x_estimate(2);
        V2_estimate_2RC = x_estimate(3);

        % Store the updated state vector for 2RC
        x_estimate_2RC_all(k, :) = x_estimate';

        % Update the error covariance for 2RC
        P_estimate_2RC = (eye(3) - KG * H) * P_pred_2RC;

        SOC_est_2RC(k) = x_estimate(1);
        V1_est_2RC(k) = x_estimate(2);
        V2_est_2RC(k) = x_estimate(3);


        %% DRT

        % Predict SOC for DRT
        SOC_pred_DRT = SOC_estimate_DRT + (dt(k) / (Q_batt * 3600)) * noisy_I(k);

        % RC voltage predictions
        V_pred_DRT = zeros(num_RC, 1);
        if k == 1
            if s == 1
                V_prev_DRT = zeros(num_RC,1);
            else
                V_prev_DRT = V_estimate_DRT;
            end
        else
            V_prev_DRT = V_estimate_DRT;
        end

        for i = 1:num_RC
            V_pred_DRT(i) = V_prev_DRT(i) * exp(-dt(k) / (R_i(i) * C_i(i))) + noisy_I(k) * R_i(i) * (1 - exp(-dt(k) / (R_i(i) * C_i(i))));
        end

        % Form the predicted state vector for DRT
        x_pred = [SOC_pred_DRT; V_pred_DRT];

        % Store the predicted state vector for DRT
        x_pred_DRT_all(k, :) = x_pred';

        % Predict the error covariance for DRT
        A_DRT = diag([1; exp(-dt(k) ./ (R_i .* C_i))']);
        P_pred_DRT = A_DRT * P_estimate_DRT * A_DRT' + Qcov3;

        % Compute OCV_pred and dOCV_dSOC for DRT
        OCV_pred = interp1(unique_soc, unique_ocv, SOC_pred_DRT, 'linear', 'extrap');
        dOCV_dSOC = interp1(unique_soc, dOCV_dSOC_values_smooth, SOC_pred_DRT, 'linear', 'extrap');

        % Measurement matrix H for DRT
        H_DRT = [dOCV_dSOC, ones(1, num_RC)];

        % Compute the predicted voltage for DRT
        V_pred_total_DRT = OCV_pred + sum(V_pred_DRT) + R0 * noisy_I(k);

        % Compute the Kalman gain for DRT
        S_k_DRT = H_DRT * P_pred_DRT * H_DRT' + Rcov3;
        KG_DRT = (P_pred_DRT * H_DRT') / S_k_DRT;

        % Store the Kalman gain for DRT
        KG_DRT_all(k, :) = KG_DRT';

        %% Update Step for DRT

        z = noisy_V(k);
        residual_DRT = z - V_pred_total_DRT;

        % Store the residual for DRT
        residual_DRT_all(k) = residual_DRT;

        % Update the estimate for DRT
        x_estimate_DRT = x_pred + KG_DRT * residual_DRT;

        SOC_estimate_DRT = x_estimate_DRT(1);
        V_estimate_DRT = x_estimate_DRT(2:end);

        % Store the updated state vector for DRT
        x_estimate_DRT_all(k, :) = x_estimate_DRT';

        % Update the error covariance for DRT
        P_estimate_DRT = (eye(1 + num_RC) - KG_DRT * H_DRT) * P_pred_DRT;

        SOC_est_DRT(k) = SOC_estimate_DRT;
        V_est_DRT(k,:) = V_estimate_DRT';

    end

    % Update initial values for the next trip for 1RC
    initial_SOC_true = True_SOC(end);
    initial_SOC_cc = CC_SOC(end);
    initial_SOC_estimate_1RC = SOC_estimate_1RC;
    initial_P_estimate_1RC = P_estimate_1RC;
    initial_V1_estimate_1RC = V1_estimate_1RC;

    % Update initial values for the next trip for 2RC
    initial_SOC_estimate_2RC = SOC_estimate_2RC;
    initial_V1_estimate_2RC = V1_estimate_2RC;
    initial_V2_estimate_2RC = V2_estimate_2RC;
    initial_P_estimate_2RC = P_estimate_2RC;

    % Update initial values for the next trip for DRT
    initial_SOC_estimate_DRT = SOC_estimate_DRT;
    initial_V_estimate_DRT = V_estimate_DRT;
    initial_P_estimate_DRT = P_estimate_DRT;

    % Update previous trip's end time
    previous_trip_end_time = t(end);

    % Concatenate data for 1RC
    t_all = [t_all; t];
    True_SOC_all = [True_SOC_all; True_SOC];
    CC_SOC_all = [CC_SOC_all; CC_SOC];
    x_pred_1RC_all_trips = [x_pred_1RC_all_trips; x_pred_1RC_all];
    x_estimate_1RC_all_trips = [x_estimate_1RC_all_trips; x_estimate_1RC_all];
    KG_1RC_all_trips = [KG_1RC_all_trips; KG_1RC_all];
    residual_1RC_all_trips = [residual_1RC_all_trips; residual_1RC_all];
    I_all = [I_all; I];
    noisy_I_all = [noisy_I_all; noisy_I];

    % Concatenate data for 2RC
    x_pred_2RC_all_trips = [x_pred_2RC_all_trips; x_pred_2RC_all];
    x_estimate_2RC_all_trips = [x_estimate_2RC_all_trips; x_estimate_2RC_all];
    KG_2RC_all_trips = [KG_2RC_all_trips; KG_2RC_all];
    residual_2RC_all_trips = [residual_2RC_all_trips; residual_2RC_all];

    % Concatenate data for DRT
    x_pred_DRT_all_trips = [x_pred_DRT_all_trips; x_pred_DRT_all];
    x_estimate_DRT_all_trips = [x_estimate_DRT_all_trips; x_estimate_DRT_all];
    KG_DRT_all_trips = [KG_DRT_all_trips; KG_DRT_all];
    residual_DRT_all_trips = [residual_DRT_all_trips; residual_DRT_all];

end

% Now plotting using the concatenated variables

% 컬러 정의 (RGB)
color_true = [0, 0, 0];                % Black
color_cc   = [0,0.4470,0.7410];        % Blue tone
color_1rc  = [0.8350,0.3333,0.0000];   % Orange tone
color_2rc  = [0.9020,0.6235,0.0000];   % Gold tone
color_drt  = [0.8,0.4745,0.6549];      % Purple tone

%% Plotting for 1RC Model
figure('Name', '1RC Model Results');
subplot(4,1,1);
hold on;
plot(t_all, True_SOC_all, 'k-', 'LineWidth', 1.5, 'DisplayName', 'True SOC');
plot(t_all, CC_SOC_all, 'b-', 'LineWidth', 1.5, 'DisplayName', 'CC SOC');
plot(t_all, x_estimate_1RC_all_trips(:,1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (1RC)');
ylabel('SOC');
xlabel('Time [s]');
title('SOC over Time (1RC)');
legend('show', 'Location', 'best');
hold off;

subplot(4,1,2);
plot(t_all, x_estimate_1RC_all_trips(:,2), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Estimated V1 (1RC)');
ylabel('Voltage [V]');
xlabel('Time [s]');
title('V1 over Time (1RC)');
legend('show', 'Location', 'best');

subplot(4,1,3);
yyaxis left;
plot(t_all, KG_1RC_all_trips(:,1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kalman Gain SOC (1RC)');
ylabel('Kalman Gain for SOC');
yyaxis right;
plot(t_all, residual_1RC_all_trips, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Residual (1RC)');
ylabel('Residual');
xlabel('Time [s]');
title('Kalman Gain and Residual over Time (1RC)');
legend('show', 'Location', 'best');

subplot(4,1,4);
plot(t_all, residual_1RC_all_trips, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Residual (1RC)');
xlabel('Time [s]');
ylabel('Residual');
title('Residual over Time (1RC)');
legend('show', 'Location', 'best');

%% Plotting for 2RC Model
figure('Name', '2RC Model Results');
subplot(4,1,1);
hold on;
plot(t_all, True_SOC_all, 'k-', 'LineWidth', 1.5, 'DisplayName', 'True SOC');
plot(t_all, CC_SOC_all, 'b-', 'LineWidth', 1.5, 'DisplayName', 'CC SOC');
plot(t_all, x_estimate_2RC_all_trips(:,1), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (2RC)');
ylabel('SOC');
xlabel('Time [s]');
title('SOC over Time (2RC)');
legend('show', 'Location', 'best');
hold off;

subplot(4,1,2);
plot(t_all, x_estimate_2RC_all_trips(:,2), 'g--', 'LineWidth', 1.5, 'DisplayName', 'Estimated V1 (2RC)');
ylabel('Voltage [V]');
xlabel('Time [s]');
title('V1 over Time (2RC)');
legend('show', 'Location', 'best');

subplot(4,1,3);
plot(t_all, x_estimate_2RC_all_trips(:,3), 'm--', 'LineWidth', 1.5, 'DisplayName', 'Estimated V2 (2RC)');
ylabel('Voltage [V]');
xlabel('Time [s]');
title('V2 over Time (2RC)');
legend('show', 'Location', 'best');

subplot(4,1,4);
yyaxis left;
plot(t_all, KG_2RC_all_trips(:,1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kalman Gain SOC (2RC)');
ylabel('Kalman Gain for SOC');
yyaxis right;
plot(t_all, residual_2RC_all_trips, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Residual (2RC)');
ylabel('Residual');
xlabel('Time [s]');
title('Kalman Gain and Residual over Time (2RC)');
legend('show', 'Location', 'best');

%% Plotting for DRT Model
figure('Name', 'DRT Model Results');
subplot(4,1,1);
hold on;
plot(t_all, True_SOC_all, 'k-', 'LineWidth', 1.5, 'DisplayName', 'True SOC');
plot(t_all, CC_SOC_all, 'b-', 'LineWidth', 1.5, 'DisplayName', 'CC SOC');
plot(t_all, x_estimate_DRT_all_trips(:,1), 'm-', 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (DRT)');
ylabel('SOC');
xlabel('Time [s]');
title('SOC over Time (DRT)');
legend('show', 'Location', 'best');
hold off;

subplot(4,1,2);
plot(t_all, sum(x_estimate_DRT_all_trips(:,2:end), 2), 'c--', 'LineWidth', 1.5, 'DisplayName', 'Estimated V (DRT)');
ylabel('Voltage [V]');
xlabel('Time [s]');
title('Total V over Time (DRT)');
legend('show', 'Location', 'best');

subplot(4,1,3);
yyaxis left;
plot(t_all, KG_DRT_all_trips(:,1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kalman Gain SOC (DRT)');
ylabel('Kalman Gain for SOC');
yyaxis right;
plot(t_all, residual_DRT_all_trips, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Residual (DRT)');
ylabel('Residual');
xlabel('Time [s]');
title('Kalman Gain and Residual over Time (DRT)');
legend('show', 'Location', 'best');

subplot(4,1,4);
plot(t_all, residual_DRT_all_trips, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Residual (DRT)');
xlabel('Time [s]');
ylabel('Residual');
title('Residual over Time (DRT)');
legend('show', 'Location', 'best');

%% SOC Comparison Plot
figure('Name', 'SOC Comparison Across Models');
plot(t_all, True_SOC_all, 'Color', color_true, 'LineWidth', 1.5, 'DisplayName', 'True SOC');
hold on;
plot(t_all, CC_SOC_all, 'Color', color_cc, 'LineWidth', 1.5, 'DisplayName', 'CC SOC');
plot(t_all, x_estimate_1RC_all_trips(:,1), 'Color', color_1rc, 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (1RC)');
plot(t_all, x_estimate_2RC_all_trips(:,1), 'Color', color_2rc, 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (2RC)');
plot(t_all, x_estimate_DRT_all_trips(:,1), 'Color', color_drt, 'LineWidth', 1.5, 'DisplayName', 'Estimated SOC (DRT)');
xlabel('Time [s]');
ylabel('SOC');
title('SOC Comparison Across Models');
legend('show', 'Location', 'best');
hold off;

%% SOC Error Comparison
figure('Name', 'SOC Error Comparison');
plot(t_all, x_estimate_1RC_all_trips(:,1) - True_SOC_all, 'Color', color_1rc, 'LineWidth', 1.5, 'DisplayName', '1RC-KF SOC Error');
hold on;
plot(t_all, x_estimate_2RC_all_trips(:,1) - True_SOC_all, 'Color', color_2rc, 'LineWidth', 1.5, 'DisplayName', '2RC-KF SOC Error');
plot(t_all, x_estimate_DRT_all_trips(:,1) - True_SOC_all, 'Color', color_drt, 'LineWidth', 1.5, 'DisplayName', 'DRT-KF SOC Error');
plot(t_all, CC_SOC_all - True_SOC_all, 'Color', color_cc, 'LineWidth', 1.5, 'DisplayName', 'CC SOC Error');
xlabel('Time [s]');
ylabel('SOC Error');
title('SOC Error Comparison');
legend('show', 'Location', 'best');
hold off;

% Current Noise 
figure;
plot(t_all, I_all - noisy_I_all, 'LineWidth', 1.5);
xlabel('Time [s]');
ylabel('Noise');
title('Current Noise (I - noisy\_I)');

% dOCV/dSOC 
figure;
plot(unique_soc, dOCV_dSOC_values_smooth, 'LineWidth', 1.5);
xlabel('SOC');
ylabel('dOCV/dSOC');
title('Derivative of OCV with respect to SOC');
grid on;


%% Function for Adding Markov Noise
function [noisy_I] = Markov(I, epsilon_percent_span)

    % Define noise parameters
    sigma_percent = 0.001;      % Standard deviation in percentage (adjust as needed)

    N = 51; % Number of states
    epsilon_vector = linspace(-epsilon_percent_span/2, epsilon_percent_span/2, N); % From -noise_percent/2 to +noise_percent/2
    sigma = sigma_percent; % Standard deviation

    % Initialize transition probability matrix P
    P = zeros(N);
    for i = 1:N
        probabilities = normpdf(epsilon_vector, epsilon_vector(i), sigma);
        P(i, :) = probabilities / sum(probabilities); % Normalize to sum to 1
    end

    % Initialize state tracking
    initial_state = 48; 
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
