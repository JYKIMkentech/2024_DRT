clc; clear; close all;

%% 설정
lambda_values = logspace(-4, 9, 5);
tau_min = 0.1;

%% 데이터 로드
save_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_lambda\';
file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_new\';
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
selected_dataset_name = datasets{dataset_idx};
if ~exist(selected_dataset_name, 'var')
    error('선택한 데이터셋이 로드되지 않았습니다.');
end
selected_dataset = eval(selected_dataset_name);

%% 타입 선택 및 데이터 준비
types = unique({selected_dataset.type});
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
type_data = selected_dataset(type_indices);
if isempty(type_data)
    error('선택한 타입에 해당하는 데이터가 없습니다.');
end
SN_list = [type_data.SN];

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
scenario_numbers = SN_list; % 시나리오 번호 리스트
validation_indices = nchoosek(scenario_numbers, 2); % 가능한 모든 2개 시나리오 조합 (28개)
num_folds = size(validation_indices, 1);
cve_lambda = zeros(length(lambda_values), 1); % 각 람다에 대한 CVE를 저장할 벡터

% 정규화 매트릭스 L 생성 (일차 차분)
n = type_data(1).n; % 모든 데이터에 대해 n이 동일하다고 가정
L = zeros(n-1, n);
for i = 1:n-1
    L(i, i) = -1;
    L(i, i+1) = 1;
end

% Lambda 값에 따른 크로스 밸리데이션 진행
for lambda_idx = 1:length(lambda_values)
    lambda_hat = lambda_values(lambda_idx);
    error_total = 0;
    
    % 각 폴드에 대해 크로스 밸리데이션 수행
    for fold_idx = 1:num_folds
        % 검증 시나리오 인덱스
        val_scenarios = validation_indices(fold_idx, :);
        
        % 학습 시나리오 인덱스 (전체에서 검증 시나리오를 제외)
        train_scenarios = setdiff(scenario_numbers, val_scenarios);
        
        W_total = [];
        y_total = [];
        
       % 학습 데이터에 대한 W와 y_adjusted 계산 및 합치기
        for train_SN = train_scenarios
            % 해당 SN을 가진 데이터를 찾기
            data_train_idx = find([type_data.SN] == train_SN);
            data_train = type_data(data_train_idx);
            
            % 필드 이름을 실제 데이터에 맞게 수정
            t_train = data_train.t;        % 예: 'time'으로 수정
            ik_train = data_train.I;    % 예: 'current'로 수정
            V_sd_train = data_train.V;  % 예: 'voltage'로 수정
            n_train = data_train.n;
            dt_train = data_train.dt;
            dur_train = data_train.dur;
            OCV_train = 0;
            R0_train = 0.1;
            
            [W_train, y_adjusted_train] = compute_W_y(t_train, ik_train, V_sd_train, n_train, dt_train, dur_train, OCV_train, R0_train);
            W_total = [W_total; W_train];
            y_total = [y_total; y_adjusted_train];
        end

        
        % 이차 프로그래밍 문제 설정 및 해결
        H = 2 * (W_total' * W_total + lambda_hat * (L' * L));
        f = -2 * W_total' * y_total;
        A_ineq = -eye(n);
        b_ineq = zeros(n, 1);
        options = optimoptions('quadprog', 'Display', 'off');
        gamma_est = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);
        
        % 검증 데이터에 대한 에러 계산
        for val_SN = val_scenarios
            % 해당 SN을 가진 데이터를 찾기
            data_val_idx = find([type_data.SN] == val_SN);
            data_val = type_data(data_val_idx);
            
            t_val = data_val.t;
            ik_val = data_val.I;
            V_sd_val = data_val.V;
            n_val = data_val.n;
            dt_val = data_val.dt;
            dur_val = data_val.dur;
            OCV_val = 0;
            R0_val = 0.1;
            
            [W_val, ~] = compute_W_y(t_val, ik_val, V_sd_val, n_val, dt_val, dur_val, OCV_val, R0_val);
            V_est_val = OCV_val + R0_val * ik_val + W_val * gamma_est;
            error = sum((V_sd_val - V_est_val).^2);
            error_total = error_total + error;
        end
    end
    
    cve_lambda(lambda_idx) = error_total;
end

% 최소 CVE를 갖는 lambda_hat 찾기
[min_cve, min_idx] = min(cve_lambda);
lambda_hat = lambda_values(min_idx);

% 결과 출력
fprintf('최적의 Lambda_hat: %e\n', lambda_hat);

% 결과 저장
selected_dataset.Lambda_vec = lambda_values;
selected_dataset.CVE = cve_lambda;
selected_dataset.Lambda_hat = lambda_hat;

%% DRT 해를 구하고 결과 저장
% 최적의 Lambda_hat을 사용하여 전체 학습 데이터로 gamma_est 계산
W_total = [];
y_total = [];

% 학습 데이터 인덱스 (첫 8개 사용)
train_scenarios = scenario_numbers(1:8);

for train_SN = train_scenarios
    data_train_idx = find([type_data.SN] == train_SN);
    data_train = type_data(data_train_idx);
    
    t_train = data_train.t;
    ik_train = data_train.ik;
    V_sd_train = data_train.V_sd;
    n_train = data_train.n;
    dt_train = data_train.dt;
    dur_train = data_train.dur;
    OCV_train = data_train.OCV;
    R0_train = data_train.R0;
    
    [W_train, y_adjusted_train] = compute_W_y(t_train, ik_train, V_sd_train, n_train, dt_train, dur_train, OCV_train, R0_train);
    W_total = [W_total; W_train];
    y_total = [y_total; y_adjusted_train];
end

% 최적의 Lambda_hat으로 gamma_est 계산
H = 2 * (W_total' * W_total + lambda_hat * (L' * L));
f = -2 * W_total' * y_total;
A_ineq = -eye(n);
b_ineq = zeros(n, 1);
options = optimoptions('quadprog', 'Display', 'off');
gamma_est = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

% gamma_est를 사용하여 테스트 데이터에 대한 예측 수행 및 에러 계산
error_total_test = 0;
test_scenarios = scenario_numbers(9:10);

for test_SN = test_scenarios
    data_test_idx = find([type_data.SN] == test_SN);
    data_test = type_data(data_test_idx);
    
    t_test = data_test.t;
    ik_test = data_test.ik;
    V_sd_test = data_test.V_sd;
    n_test = data_test.n;
    dt_test = data_test.dt;
    dur_test = data_test.dur;
    OCV_test = data_test.OCV;
    R0_test = data_test.R0;
    
    [W_test, ~] = compute_W_y(t_test, ik_test, V_sd_test, n_test, dt_test, dur_test, OCV_test, R0_test);
    V_est_test = OCV_test + R0_test * ik_test + W_test * gamma_est;
    error = sum((V_sd_test - V_est_test).^2);
    error_total_test = error_total_test + error;
end

fprintf('테스트 데이터에 대한 총 에러: %f\n', error_total_test);

% 결과 저장
selected_dataset.Gamma_est = gamma_est;

%% 함수 정의

function [W, y_adjusted] = compute_W_y(t, ik, V_sd, n, dt, dur, OCV, R0)
    % W 행렬과 y_adjusted 벡터를 계산하는 함수
    tau_min = 0.1;  % 최소 tau 값 (초)
    tau_max = dur;   % 최대 tau 값 (초)
    theta_min = log(tau_min);
    theta_max = log(tau_max);
    theta_discrete = linspace(theta_min, theta_max, n)';
    delta_theta = theta_discrete(2) - theta_discrete(1);
    tau_discrete = exp(theta_discrete);

    % W 행렬 설정
    W = zeros(length(t), n);
    for k_idx = 1:length(t)
        if k_idx == 1
            for i = 1:n
                W(k_idx, i) = ik(k_idx) * (1 - exp(-dt / tau_discrete(i))) * delta_theta;
            end
        else
            for i = 1:n
                W(k_idx, i) = W(k_idx-1, i) * exp(-dt / tau_discrete(i)) + ...
                              ik(k_idx) * (1 - exp(-dt / tau_discrete(i))) * delta_theta;
            end
        end
    end

    % y_adjusted 계산
    y_adjusted = V_sd - OCV - R0 * ik;
end

