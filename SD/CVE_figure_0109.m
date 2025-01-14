clc; clear; close all;

%% Description
% This script performs DRT estimation with uncertainty analysis using bootstrap.
% It loads the data, allows the user to select a dataset and type, and then
% performs the DRT estimation and uncertainty analysis for each scenario within the selected data.
% The estimated gamma values are plotted with uncertainty bounds and compared with the true gamma.

%% Graphic Parameters
axisFontSize   = 14;
titleFontSize  = 12;
legendFontSize = 12;
labelFontSize  = 12;

%% Load Data
% Set the file path to the directory containing the .mat files
%file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_new\';
file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_lambda\';
mat_files = dir(fullfile(file_path, '*.mat'));

% Load all .mat files in the specified folder
for file = mat_files'
    load(fullfile(file_path, file.name));
end

%% Parameters
% List of datasets and their names
AS_structs = {AS1_1per_new, AS1_2per_new, AS2_1per_new, AS2_2per_new};
AS_names   = {'AS1_1per_new', 'AS1_2per_new', 'AS2_1per_new', 'AS2_2per_new'};
Gamma_structs = {Gamma_unimodal, Gamma_unimodal, Gamma_bimodal, Gamma_bimodal};

% Select the dataset to process
fprintf('Available datasets:\n');
for idx = 1:length(AS_names)
    fprintf('%d: %s\n', idx, AS_names{idx});
end
dataset_idx = input('Select a dataset to process (enter the number): ');

% Set the selected dataset
AS_data    = AS_structs{dataset_idx};
AS_name    = AS_names{dataset_idx};
Gamma_data = Gamma_structs{dataset_idx};

% Extract the list of available types from the selected dataset
types = unique({AS_data.type});

% Type selection
disp('Select a type:');
for i = 1:length(types)
    fprintf('%d. %s\n', i, types{i});
end
type_idx = input('Enter the type number: ');
selected_type = types{type_idx};

% Extract data for the selected type
type_indices = find(strcmp({AS_data.type}, selected_type));
type_data    = AS_data(type_indices);

% Display the scenario numbers (SN) that exist for this type
SN_list = [type_data.SN];
fprintf('\nSelected dataset: %s\n', AS_name);
fprintf('Selected type: %s\n', selected_type);
fprintf('Scenario numbers available: ');
disp(SN_list);

%% SN=1 시나리오의 CVE vs lambda 플롯 (시나리오 상관 없이 동일하다 가정)
% SN=1인 시나리오를 찾는다.
scenario_idx = find([type_data.SN] == 1, 1);  % 첫 번째 SN=1 인덱스
if isempty(scenario_idx)

    error('해당 타입에 SN=1 시나리오가 존재하지 않습니다.');
end

% lambda, CVE, optimal lambda 가져오기
lambda_grids   = type_data(scenario_idx).Lambda_vec;  % 예: 1x50 double
CVE_total      = type_data(scenario_idx).CVE;         % 예: 50x1 double
optimal_lambda = type_data(scenario_idx).Lambda_hat;  % 예: 19.3070

% optimal_lambda가 lambda_grids 중 어디에 있는지 인덱스를 찾는다
[~, optimal_idx] = min(abs(lambda_grids - optimal_lambda));

% CVE vs lambda 플롯
figure;
semilogx(lambda_grids, CVE_total, 'b-', 'LineWidth', 1.5); hold on;
semilogx(optimal_lambda, CVE_total(optimal_idx), 'ro', 'MarkerSize', 10, 'LineWidth', 2);

xlabel('\lambda', 'FontSize', labelFontSize);
ylabel('CVE', 'FontSize', labelFontSize);

% title 수정: 예) "type A : CVE vs λ"
title(['type ' selected_type ' : CVE vs \lambda'], 'FontSize', titleFontSize);
ylim([2608.05 2608.08])

grid on;
legend({'CVE', ['Optimal \lambda = ', num2str(optimal_lambda, '%.2e')]}, 'Location', 'best');
hold off;

