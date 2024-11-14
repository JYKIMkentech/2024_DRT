clc; clear; close all;

%% Description

% This script performs DRT estimation on selected datasets and types.
% It loads the data, allows you to select a dataset and type, and then
% performs the DRT estimation for each scenario within the selected data.
% The estimated gamma values are plotted and compared with the true gamma
% without interpolating the true gamma values.

%% Graphics settings

axisFontSize = 14;
titleFontSize = 12;
legendFontSize = 12;
labelFontSize = 12;

%% Load data

% Set the file path to the directory containing the .mat files
file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_new\';

% Get list of .mat files in the directory
mat_files = dir(fullfile(file_path, '*.mat')); % AS1_1per_new, AS1_2per_new, AS2_1per_new, AS2_2per_new, Unimodal_gamma, Bimodal_gamma

% Load the data files
for file = mat_files'
    load(fullfile(file_path, file.name));
end

%% Dataset selection

% List of datasets
datasets = {'AS1_1per_new', 'AS1_2per_new', 'AS2_1per_new', 'AS2_2per_new'};

% Display datasets and allow the user to select one
disp('Select a dataset:');
for i = 1:length(datasets)
    fprintf('%d. %s\n', i, datasets{i});
end
dataset_idx = input('Enter the dataset number: ');
selected_dataset_name = datasets{dataset_idx};
selected_dataset = eval(selected_dataset_name);

%% Type selection

% Extract the list of available types from the selected dataset
types = unique({selected_dataset.type});

% Display the types and allow the user to select one
disp('Select a type:');
for i = 1:length(types)
    fprintf('%d. %s\n', i, types{i});
end
type_idx = input('Enter the type number: ');
selected_type = types{type_idx};

% Extract data for the selected type
type_indices = find(strcmp({selected_dataset.type}, selected_type));
type_data = selected_dataset(type_indices);

% Extract scenario numbers
SN_list = [type_data.SN];

% Display selected dataset, type, and scenario numbers
fprintf('Selected dataset: %s\n', selected_dataset_name);
fprintf('Selected type: %s\n', selected_type);
fprintf('Scenario numbers: ');
disp(SN_list);

%% DRT Estimation

% Load the true gamma(theta) for comparison
% For AS1 datasets, the true gamma is Unimodal_gamma
% For AS2 datasets, the true gamma is Bimodal_gamma

if contains(selected_dataset_name, 'AS1')
    true_gamma_data = Gamma_unimodal;
elseif contains(selected_dataset_name, 'AS2')
    true_gamma_data = Gamma_bimodal;
else
    error('Unknown dataset name');
end

% Number of scenarios
num_scenarios = length(type_data);

% Initialize variables to store results
gamma_est_all = cell(num_scenarios, 1); % To store gamma estimates
V_est_all = cell(num_scenarios, 1);    % To store V_est
V_sd_all = cell(num_scenarios, 1);     % To store V_sd

% Colors for plotting
c_mat = lines(num_scenarios);

% For each scenario
for s = 1:num_scenarios
    fprintf('Processing Scenario %d/%d...\n', s, num_scenarios);
    
    % Get data for current scenario
    scenario_data = type_data(s);
    
    % Extract necessary data
    t = scenario_data.t;          % Time vector
    ik = scenario_data.I;         % Current vector
    V_sd = scenario_data.V;       % Measured voltage vector
    lambda_hat = 0.518;           % Regularization parameter (modify if available in data)
    n = scenario_data.n;          % Number of RC elements
    dt = scenario_data.dt;        % Sampling time
    dur = scenario_data.dur;      % Duration (tau_max)
    
    % Set up other parameters
    OCV = 0;                      % Open Circuit Voltage (modify if necessary)
    R0 = 0.1;                     % Initial resistance (adjust if necessary)
    
    % Call the DRT estimation function
    [gamma_est, V_est, theta_discrete, tau_discrete, W] = DRT_estimation(t, ik, V_sd, lambda_hat, n, dt, dur, OCV, R0);
    
    % Save the results
    gamma_est_all{s} = gamma_est;
    V_est_all{s} = V_est;
    V_sd_all{s} = V_sd;
end

%% Plotting Results

% Plot the estimated gamma for all scenarios
figure('Name', ['Estimated Gamma for ', selected_dataset_name, ' Type ', selected_type], 'NumberTitle', 'off');
hold on;
for s = 1:num_scenarios
    plot(theta_discrete, gamma_est_all{s}, '--', 'LineWidth', 1.5, ...
        'Color', c_mat(s, :), 'DisplayName', ['Scenario ', num2str(SN_list(s))]);
end
% Plot the true gamma without interpolation
plot(true_gamma_data.theta, true_gamma_data.gamma, 'k-', 'LineWidth', 2, 'DisplayName', 'True \gamma');
hold off;
xlabel('\theta = ln(\tau [s])', 'FontSize', labelFontSize);
ylabel('\gamma', 'FontSize', labelFontSize);
title(['Estimated \gamma for ', selected_dataset_name, ' Type ', selected_type], 'FontSize', titleFontSize);
set(gca, 'FontSize', axisFontSize);
legend('Location', 'Best', 'FontSize', legendFontSize);

% Optionally, select specific scenarios to plot
selected_scenarios = input('Enter scenario numbers to plot (e.g., [1,2,3]): ');

% Plot the estimated gamma for selected scenarios
figure('Name', ['Estimated Gamma for Selected Scenarios in ', selected_dataset_name, ' Type ', selected_type], 'NumberTitle', 'off');
hold on;
for idx = 1:length(selected_scenarios)
    s = find(SN_list == selected_scenarios(idx));
    if ~isempty(s)
        plot(theta_discrete, gamma_est_all{s}, '--', 'LineWidth', 1.5, ...
            'Color', c_mat(s, :), 'DisplayName', ['Scenario ', num2str(SN_list(s))]);
    else
        warning('Scenario %d not found in the data', selected_scenarios(idx));
    end
end
% Plot the true gamma without interpolation
plot(true_gamma_data.theta, true_gamma_data.gamma, 'k-', 'LineWidth', 2, 'DisplayName', 'True \gamma');
hold off;
xlabel('\theta = ln(\tau [s])', 'FontSize', labelFontSize);
ylabel('\gamma', 'FontSize', labelFontSize);
title(['Estimated \gamma for Selected Scenarios in ', selected_dataset_name, ' Type ', selected_type], 'FontSize', titleFontSize);
set(gca, 'FontSize', axisFontSize);
legend('Location', 'Best', 'FontSize', legendFontSize);
