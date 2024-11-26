clc; clear; close all;

%% Font size settings
axisFontSize = 14;
titleFontSize = 16;
legendFontSize = 12;
labelFontSize = 14;

%% 1. Data Loading

% ECM parameters (from HPPC test)
load('optimized_params_struct_final_2RC.mat'); % Fields: R0, R1, C1, R2, C2, SOC, avgI, m, Crate

% DRT parameters (gamma and tau values)
load('theta_discrete.mat');
load('gamma_est_all');
load('R0_est_all.mat');
tau_discrete = exp(theta_discrete); % tau values

% SOC-OCV lookup table (from C/20 test)
load('soc_ocv.mat', 'soc_ocv'); % [SOC, OCV]
soc_values = soc_ocv(:, 1);     % SOC values
ocv_values = soc_ocv(:, 2);     % Corresponding OCV values [V]

% Driving data (17 trips)
load('udds_data.mat'); % Struct array 'udds_data' with fields: V, I, t, Time_duration, SOC

%% 2. Common Settings

%I_1C = 2.8892;           % 1C current [A]
Config.cap = 2.7742;       % Nominal capacity [Ah]
Config.coulomb_efficiency = 1; % Coulomb efficiency

% Remove duplicate OCV values for interpolation
[unique_ocv_values, unique_idx] = unique(ocv_values);
unique_soc_values = soc_values(unique_idx);

%% 3. ECM Parameter Preparation (from HPPC)

% Target C-rate (0.5C)
Crate_target = 0.5;

% Extract ECM parameters from HPPC
SOC_param_all = [optimized_params_struct_final_2RC.SOC];
R0_param_all = [optimized_params_struct_final_2RC.R0];
R1_param_all = [optimized_params_struct_final_2RC.R1];
C1_param_all = [optimized_params_struct_final_2RC.C1];
R2_param_all = [optimized_params_struct_final_2RC.R2];
C2_param_all = [optimized_params_struct_final_2RC.C2];
Crate_param_all = [optimized_params_struct_final_2RC.Crate];

% Find indices where C-rate is 0.5C (considering floating-point errors)
tolerance = 1e-3;
indices_Crate_05 = abs(Crate_param_all - Crate_target) < tolerance;

% Extract SOC and ECM parameters where C-rate is 0.5C
SOC_param = SOC_param_all(indices_Crate_05);
R0_param = R0_param_all(indices_Crate_05);
R1_param = R1_param_all(indices_Crate_05);
C1_param = C1_param_all(indices_Crate_05);
R2_param = R2_param_all(indices_Crate_05);
C2_param = C2_param_all(indices_Crate_05);

% Remove duplicate SOC values and average corresponding parameters
[SOC_param_unique, ~, idx_unique] = unique(SOC_param);

R0_param_unique = accumarray(idx_unique, R0_param, [], @mean);
R1_param_unique = accumarray(idx_unique, R1_param, [], @mean);
C1_param_unique = accumarray(idx_unique, C1_param, [], @mean);
R2_param_unique = accumarray(idx_unique, R2_param, [], @mean);
C2_param_unique = accumarray(idx_unique, C2_param, [], @mean);

% Create interpolation functions for SOC-based parameters
F_R0 = @(SOC) interp1(SOC_param_unique, R0_param_unique, SOC, 'linear', 'extrap');
F_R = @(SOC) [interp1(SOC_param_unique, R1_param_unique, SOC, 'linear', 'extrap'), ...
              interp1(SOC_param_unique, R2_param_unique, SOC, 'linear', 'extrap')];
F_C = @(SOC) [interp1(SOC_param_unique, C1_param_unique, SOC, 'linear', 'extrap'), ...
              interp1(SOC_param_unique, C2_param_unique, SOC, 'linear', 'extrap')];

%% 4. Kalman Filter Settings

% Initial covariance matrices for different models
P_init = struct();
P_init.SOC = 1e-3; % Initial variance for SOC
P_init.V_RC = 1e-3; % Initial variance for each RC voltage

% Process noise covariance (Q)
Q_params = struct();
Q_params.SOC = 1e-6; % Process noise variance for SOC
Q_params.V_RC = 1e-8; % Process noise variance for each RC voltage

% Measurement noise covariance (R)
R_noise = 5.25e-2; % Measurement noise variance

%% 5. Apply Kalman Filter to All Trips

num_trips = length(udds_data);

% Initialize arrays to store results
all_SOC_true = cell(num_trips-1, 1);
all_SOC_CC = cell(num_trips-1, 1);
all_SOC_KF = cell(num_trips-1, 1); % For 1-RC, 2-RC, and DRT models
all_Vt_meas = cell(num_trips-1, 1);
all_Vt_KF = cell(num_trips-1, 1);
all_time = cell(num_trips-1, 1);
all_current = cell(num_trips-1, 1);

% Previous trip's final state variables
X_est_prev = [];
P_prev = [];

% Previous trip's final SOC values
SOC_true_prev = [];
SOC_CC_prev = [];

% Time offset initialization
total_time_offset = 0;

% Define Color Matrix
c_mat = lines(9);  % 9 distinct colors

% Number of RC elements (set to 1 or 2)
model_options = {'RC1', 'RC2', 'DRT'}; % Include DRT model

% Loop over trips
for trip_num = 1:num_trips-1
    fprintf('Processing trip %d of %d...\n', trip_num, num_trips-1);

    %% 5.1. Extract Trip Data
    trip_current = udds_data(trip_num).I;          % Current [A]
    trip_voltage = udds_data(trip_num).V;          % Voltage [V]
    trip_time = udds_data(trip_num).Time_duration; % Cumulative time [s]
    trip_SOC_true = udds_data(trip_num).SOC;       % True SOC (if available)

    % Adjust time to start from 0 and apply time offset
    trip_time = trip_time - trip_time(1);
    trip_time = trip_time + total_time_offset;

    %% 5.2. Add Markov Noise to Current
    n = 21;
    noise_percent = 0.05;
    initial_state = randsample(1:n, 1);
    [noisy_trip_current, ~] = add_markov_noise(trip_current, n, noise_percent, initial_state);

    %% 5.3. Add 3% Gaussian Random Noise to Voltage
    voltage_noise_std = 0.03 * trip_voltage;
    noisy_trip_voltage = trip_voltage + voltage_noise_std .* randn(size(trip_voltage));

    %% 5.4. Initialization

    % Time intervals
    dt = [0; diff(trip_time)];
    if dt(1) == 0
        dt(1) = dt(2);
    end

    if trip_num == 1
        % For the first trip, estimate initial SOC from voltage
        initial_voltage = trip_voltage(1);
        initial_soc = interp1(unique_ocv_values, unique_soc_values, initial_voltage, 'linear', 'extrap');

        % Set previous SOC values
        SOC_true_prev = initial_soc;
        SOC_CC_prev = initial_soc;

        % Initialize state estimates and covariances for models
        X_est_prev = struct();
        P_prev = struct();

        for model = model_options
            model_name = model{1};

            if strcmp(model_name, 'DRT')
                % DRT-based model initialization
                num_RC_DRT = length(tau_discrete);
                state_dim_DRT = 1 + num_RC_DRT;

                % Initial gamma and R0 estimation
                gamma_current_init = interp1(soc_sorted, gamma_sorted, initial_soc, 'linear', 'extrap');
                gamma_current_init = gamma_current_init(:)'; % 1 x num_RC_DRT vector
                delta_theta = theta_discrete(2) - theta_discrete(1);
                R_i_init = gamma_current_init * delta_theta; % 1 x num_RC_DRT vector
                C_i_init = tau_discrete ./ R_i_init;         % 1 x num_RC_DRT vector

                % Initial V_RC estimation
                exp_term = exp(-dt(1) ./ (R_i_init .* C_i_init));
                V_RC_init_DRT = R_i_init .* (1 - exp_term) * noisy_trip_current(1);

                % State vector: [SOC; V_RC_1; V_RC_2; ...]
                X_est_prev.(model_name) = [initial_soc; V_RC_init_DRT'];
                P_prev.(model_name) = diag([P_init.SOC; repmat(P_init.V_RC, num_RC_DRT, 1)]);
            else
                % 1-RC and 2-RC models
                num_RC = str2double(model_name(3));
                R_init = F_R(initial_soc);
                C_init = F_C(initial_soc);
                V_RC_init = zeros(num_RC, 1);
                for i = 1:num_RC
                    R_i = R_init(i);
                    C_i = C_init(i);
                    V_RC_init(i) = noisy_trip_current(1) * R_i * (1 - exp(-dt(1) / (R_i * C_i)));
                end

                % State vector: [SOC; V_RC_1; V_RC_2; ...]
                X_est_prev.(model_name) = [initial_soc; V_RC_init];
                P_prev.(model_name) = diag([P_init.SOC; repmat(P_init.V_RC, num_RC, 1)]);
            end
        end
    end

    % Prepare storage variables
    num_samples = length(trip_time);
    SOC_save_true = zeros(num_samples, 1);
    SOC_save_CC = zeros(num_samples, 1);
    SOC_save_KF = struct();
    Vt_est_save_KF = struct();

    for model = model_options
        model_name = model{1};
        SOC_save_KF.(model_name) = zeros(num_samples, 1);
        Vt_est_save_KF.(model_name) = zeros(num_samples, 1);
    end

    Vt_meas_save = trip_voltage;
    Time_save = trip_time;
    trip_current = trip_current(:);

    % Save initial values
    SOC_save_true(1) = SOC_true_prev;
    SOC_save_CC(1) = SOC_CC_prev;

    for model = model_options
        model_name = model{1};
        SOC_save_KF.(model_name)(1) = X_est_prev.(model_name)(1);
        OCV_init = interp1(unique_soc_values, unique_ocv_values, X_est_prev.(model_name)(1), 'linear', 'extrap');

        if strcmp(model_name, 'DRT')
            Vt_est_save_KF.(model_name)(1) = OCV_init + sum(X_est_prev.(model_name)(2:end)) + R0_est_all(trip_num) * noisy_trip_current(1);
        else
            Vt_est_save_KF.(model_name)(1) = OCV_init + sum(X_est_prev.(model_name)(2:end)) + F_R0(X_est_prev.(model_name)(1)) * noisy_trip_current(1);
        end
    end

    %% 5.5. Main Loop

    for k = 2:num_samples
        % Common computations
        dt_k = trip_time(k) - trip_time(k-1);
        ik = trip_current(k);
        noisy_ik = noisy_trip_current(k);
        vk = trip_voltage(k);
        noisy_vk = noisy_trip_voltage(k);

        %% True SOC Calculation (Coulomb Counting)
        SOC_true = SOC_save_true(k-1) + (dt_k / (Config.cap * 3600)) * ik * Config.coulomb_efficiency;
        SOC_save_true(k) = SOC_true;

        %% CC SOC Calculation (with noisy current)
        SOC_CC = SOC_save_CC(k-1) + (dt_k / (Config.cap * 3600)) * noisy_ik * Config.coulomb_efficiency;
        SOC_save_CC(k) = SOC_CC;

        %% Kalman Filter Update for Each Model
        for model = model_options
            model_name = model{1};

            if strcmp(model_name, 'DRT')
                % DRT model parameters
                model_params = struct();
                model_params.model_type = 'DRT';
                model_params.gamma_sorted = gamma_sorted;
                model_params.soc_sorted = soc_sorted;
                model_params.theta_discrete = theta_discrete;
                model_params.tau_discrete = tau_discrete;
                model_params.R0 = R0_est_all(trip_num);
            else
                % RC models
                num_RC = str2double(model_name(3));
                model_params = struct();
                model_params.model_type = 'RC';
                model_params.num_RC = num_RC;
                model_params.F_R = F_R;
                model_params.F_C = F_C;
                model_params.F_R0 = F_R0;
            end

            [X_est, P_est, Vt_est] = kalman_filter_general(...
                X_est_prev.(model_name), ...
                P_prev.(model_name), ...
                noisy_ik, noisy_vk, dt_k, Config, ...
                unique_soc_values, unique_ocv_values, ...
                Q_params, R_noise, model_params);

            % Save results
            SOC_save_KF.(model_name)(k) = X_est(1);
            Vt_est_save_KF.(model_name)(k) = Vt_est;

            % Update previous state
            X_est_prev.(model_name) = X_est;
            P_prev.(model_name) = P_est;
        end
    end

    %% 5.6. Save Results

    all_SOC_true{trip_num} = SOC_save_true;
    all_SOC_CC{trip_num} = SOC_save_CC;
    all_Vt_meas{trip_num} = Vt_meas_save;
    all_time{trip_num} = Time_save;
    all_current{trip_num} = trip_current;

    for model = model_options
        model_name = model{1};
        all_SOC_KF{trip_num}.(model_name) = SOC_save_KF.(model_name);
        all_Vt_KF{trip_num}.(model_name) = Vt_est_save_KF.(model_name);
    end

    % Update previous SOC values
    SOC_true_prev = SOC_save_true(end);
    SOC_CC_prev = SOC_save_CC(end);

    % Update time offset
    total_time_offset = trip_time(end);
end

%% 6. Combine All Trips for Visualization

% Concatenate data
all_time_concat = cell2mat(all_time);
all_SOC_true_concat = cell2mat(all_SOC_true);
all_SOC_CC_concat = cell2mat(all_SOC_CC);
all_Vt_meas_concat = cell2mat(all_Vt_meas);
all_current_concat = cell2mat(all_current);

all_SOC_KF_concat = struct();
all_Vt_KF_concat = struct();

for model = model_options
    model_name = model{1};
    all_SOC_KF_concat.(model_name) = [];
    all_Vt_KF_concat.(model_name) = [];
    for trip_num = 1:num_trips-1
        all_SOC_KF_concat.(model_name) = [all_SOC_KF_concat.(model_name); all_SOC_KF{trip_num}.(model_name)];
        all_Vt_KF_concat.(model_name) = [all_Vt_KF_concat.(model_name); all_Vt_KF{trip_num}.(model_name)];
    end
end

%% 7. Visualization

figure('Name', 'All Trips Comparison', 'NumberTitle', 'off');

% Subplot 1: SOC Comparison
subplot(3,1,1);
hold on;
plot(all_time_concat, all_SOC_true_concat * 100, 'Color', c_mat(1, :), 'LineWidth', 1.5, 'DisplayName', 'True SOC');
plot(all_time_concat, all_SOC_CC_concat * 100, 'Color', c_mat(2, :), 'LineWidth', 1.5, 'DisplayName', 'CC SOC');

for idx = 1:length(model_options)
    model_name = model_options{idx};
    plot(all_time_concat, all_SOC_KF_concat.(model_name) * 100, '--', 'Color', c_mat(2+idx, :), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s Model SOC', model_name));
end

xlabel('Time [s]', 'FontSize', labelFontSize);
ylabel('SOC [%]', 'FontSize', labelFontSize);
title('All Trips: SOC Estimation using Kalman Filter', 'FontSize', titleFontSize);
legend('Location', 'best', 'FontSize', legendFontSize);
grid on;
hold off;

% Subplot 2: Terminal Voltage Comparison
subplot(3,1,2);
hold on;
plot(all_time_concat, all_Vt_meas_concat, 'Color', c_mat(1, :), 'LineWidth', 1.0, 'DisplayName', 'Measured Voltage');

for idx = 1:length(model_options)
    model_name = model_options{idx};
    plot(all_time_concat, all_Vt_KF_concat.(model_name), '--', 'Color', c_mat(2+idx, :), 'LineWidth', 1.0, ...
        'DisplayName', sprintf('Estimated Voltage (%s)', model_name));
end

xlabel('Time [s]', 'FontSize', labelFontSize);
ylabel('Terminal Voltage [V]', 'FontSize', labelFontSize);
title('All Trips: Voltage Estimation', 'FontSize', titleFontSize);
legend('Location', 'best', 'FontSize', legendFontSize);
grid on;
hold off;

% Subplot 3: Current Profile
subplot(3,1,3);
plot(all_time_concat, all_current_concat, 'Color', c_mat(6, :), 'LineWidth', 1.5);
xlabel('Time [s]', 'FontSize', labelFontSize);
ylabel('Current [A]', 'FontSize', labelFontSize);
title('All Trips: Current Profile', 'FontSize', titleFontSize);
grid on;

