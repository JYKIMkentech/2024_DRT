clc; clear; close all;

%% 설정
axisFontSize = 14;
titleFontSize = 12;
legendFontSize = 12;
labelFontSize = 12;

lambda_grids = logspace(-4, 2, 5);
num_lambdas = length(lambda_grids);
OCV = 0;
R0 = 0.1;

%% 데이터 로드
save_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_lambda\';
%file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_new\';
file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_lambda\';
mat_files = dir(fullfile(file_path, '*.mat'));
if isempty(mat_files)
    error('데이터 파일이 존재하지 않습니다. 경로를 확인해주세요.');
end
for file = mat_files'
    load(fullfile(file_path, file.name));
end

%% 데이터셋 선택
datasets = {'AS1_1per_new', 'AS1_2per_new', 'AS2_1per_new', 'AS2_2per_new'};
disp('데이터셋을 선택하세요:');
for i = 1:length(datasets)
    fprintf('%d. %s\n', i, datasets{i});
end
dataset_idx = input('데이터셋 번호를 입력하세요: ');
if isempty(dataset_idx) || dataset_idx < 1 || dataset_idx > length(datasets)
    error('유효한 데이터셋 번호를 입력해주세요.');
end
selected_dataset_name = datasets{dataset_idx}; % 선택된 dataset 당 80개 (type 8개 x 시나리오 10개) 
if ~exist(selected_dataset_name, 'var')
    error('선택한 데이터셋이 로드되지 않았습니다.');
end
selected_dataset = eval(selected_dataset_name);

%% 타입 선택 및 데이터 준비
types = unique({selected_dataset.type}); % A,B,C,..,H
disp('타입을 선택하세요:');
for i = 1:length(types)
    fprintf('%d. %s\n', i, types{i});
end
type_idx = input('타입 번호를 입력하세요: ');
if isempty(type_idx) || type_idx < 1 || type_idx > length(types)
    error('유효한 타입 번호를 입력해주세요.');
end
selected_type = types{type_idx};
type_indices = strcmp({selected_dataset.type}, selected_type);
type_data = selected_dataset(type_indices); % 80개 중 , 선택된 type에 해당하는 시나리오 10개 선택 (eg. type_data = 'AS1_1per_new', 'A' type인 10개 시나리오 선택됨)
if isempty(type_data)
    error('선택한 타입에 해당하는 데이터가 없습니다.');
end
SN_list = [type_data.SN]; % SN = 시나리오 넘버

%% 새로운 필드 추가 
new_fields = {'Lambda_vec', 'CVE', 'Lambda_hat'};
num_elements = length(selected_dataset);
empty_fields = repmat({[]}, 1, num_elements);

for nf = 1:length(new_fields)
    field_name = new_fields{nf};
    if ~isfield(selected_dataset, field_name)
        [selected_dataset.(field_name)] = empty_fields{:};
    end
end


%% 람다 최적화 및 교차 검증
scenario_numbers = SN_list; % 시나리오 넘버
validation_combinations = nchoosek(scenario_numbers, 2); % 조합 가능 수 
num_folds = size(validation_combinations, 1); % 10C2 = 45 folds
CVE_total = zeros(num_lambdas,1); % 45개 folds 경우 수에 대하여 CVE을 모두 더함 = CVE_total

for m = 1 : num_lambdas  % 모든 lamda에 대해서 loop
    lambda = lambda_grids(m);
    CVE = 0 ;


    for f = 1 : num_folds % 1개 lambda에 대해, 전체 folds 에 대해서 loop
        val_trips = validation_combinations(f,:);
        train_trips = setdiff(1 : length(type_data), val_trips) ;

        W_total = [];
        y_total = [];


        for s = train_trips % 검증/학습 데이터 셋이 정해지면 1개 folds에 대해, W_total, y_total 계산 

            t = type_data(s).t;
            dt = [t(1); diff(t)];
            dur = type_data(s).dur;
            n = type_data(s).n;
            I = type_data(s).I;
            V = type_data(s).V;
            

            [~, ~, ~, ~, W, y] = DRT_estimation(t, I, V, lambda, n, dt, dur, OCV, R0);

            W_total = [W_total; W]; % W 행렬 이어 붙이기 
            y_total = [y_total; y]; % y 행렬 이어 붙이기 
            
        end

        [gamma_total] = DRT_estimation_with_Wy(W_total, y_total, lambda);

        for j = val_trips
            t = type_data(j).t;
            dt = [t(1); diff(t)];
            dur = type_data(j).dur;
            n = type_data(j).n;
            I = type_data(j).I;
            V = type_data(j).V;
            
            [~, ~, ~, ~, W_val, ~] = DRT_estimation(t, I, V, lambda, n, dt, dur, OCV,R0);
            V_est = OCV + I * R0 + W_val * gamma_total;

            error = sum((V - V_est).^2);
            CVE = CVE + error;
        end
    end

    CVE_total(m) = CVE; % lambda 후보군에 해당하는 CVE 저장 
    fprintf('Lambda: %.2e, CVE: %.4f\n', lambda, CVE_total(m));


end

[~, optimal_idx] = min(CVE_total);
optimal_lambda = lambda_grids(optimal_idx);

%% 결과 저장
for i = 1:length(type_data)
    type_data(i).Lambda_vec = lambda_grids;
    type_data(i).CVE = CVE_total;
    type_data(i).Lambda_hat = optimal_lambda;
end
selected_dataset(type_indices) = type_data;
%assignin('base', selected_dataset_name, selected_dataset);

%% 데이터 저장

% 폴더가 존재하지 않으면 생성
if ~exist(save_path, 'dir')
    mkdir(save_path);
end
% 선택된 데이터셋을 지정된 폴더에 저장
save(fullfile(save_path, [selected_dataset_name, '.mat']), selected_dataset_name);
fprintf('Updated dataset saved to %s\n', fullfile(save_path, [selected_dataset_name, '.mat']));

%% 5. Plot (CVE vs lambda)

figure;
semilogx(lambda_grids, CVE_total, 'b-', 'LineWidth', 1.5); hold on;
semilogx(optimal_lambda, CVE_total(optimal_idx), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('\lambda', 'FontSize', labelFontSize);
ylabel('CVE', 'FontSize', labelFontSize);
title('CVE vs \lambda ', 'FontSize', titleFontSize);
grid on;
legend({'CVE', ['Optimal \lambda = ', num2str(optimal_lambda, '%.2e')]}, 'Location', 'best');
%ylim([534.19912 534.19913])

hold off;




%% function 


% (W,Y 주어졌을때 gamma 해 구하기)
function [gamma_total] = DRT_estimation_with_Wy(W_total, y_total, lambda)
    W_total_n = size(W_total, 2) ; % Number of gamma parameters
    
    L = zeros(W_total_n-1, W_total_n);
    for i = 1:W_total_n-1
        L(i, i) = -1;
        L(i, i+1) = 1;
    end

    % Set up the quadratic programming problem
    H = 2 * (W_total' * W_total + lambda * (L' * L));
    f = -2 * W_total' * y_total;

    % Inequality constraints: params >= 0
    A_ineq = -eye(W_total_n);
    b_ineq = zeros(W_total_n , 1);

    % Solve the quadratic programming problem
    options = optimoptions('quadprog', 'Display', 'off');
    gamma_total = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);  
end







