clear; clc;  close all;

%% 0. Font Size and Color Matrix Settings
% Font Size Settings
axisFontSize = 14;      % Axis number size
titleFontSize = 16;     % Title font size
legendFontSize = 12;    % Legend font size
labelFontSize = 14;     % xlabel and ylabel font size

% Color Matrix Settings
c_mat = lines(9);  % Define 9 unique colors

% 1. 데이터 로드
% UDDS 주행 데이터를 로드합니다.
load('udds_data.mat');  % 'udds_data' 구조체를 로드합니다.

% SOC-OCV 데이터를 로드합니다.
load('soc_ocv.mat', 'soc_ocv');
soc_values = soc_ocv(:, 1);  % SOC 값
ocv_values = soc_ocv(:, 2);  % OCV 값

%% 2. Parameter 설정

n = 201;
dur = 1370; % [sec]
SOC_begin = 0.9907 ; % 0.9907;
Q_batt = 2.93; % [Ah]

lambda_grids = logspace(-5, 2, 10);  
num_lambdas = length(lambda_grids);

%% 3. 전체 trip에 대해 SOC 계산 --> OCV update 할때 필요

for u = 1:length(udds_data)
    t = udds_data(u).t;
    dt = [t(1); diff(t)];
    I = udds_data(u).I;
    udds_data(u).SOC = SOC_begin + cumtrapz(t,I) / (Q_batt * 3600);
    SOC_begin = udds_data(u).SOC(end);
end


%% 4. Cross-Validation loop

validation_combinations = nchoosek(1 : length(udds_data)-1, 2); % 마지막 17번째 data 시간 부족으로 CV 참여 x
num_folds = size(validation_combinations, 1);
CVE_total = zeros(num_lambdas, 1);

for m = 1 : num_lambdas  % 모든 lamda에 대해서 loop
    lambda = lambda_grids(m);
    CVE = 0 ; 
    
    for f = 1 : num_folds % 1개 lambda에 대해, 전체 folds 에 대해서 loop
        val_trips = validation_combinations(f,:);
        train_trips = setdiff(1 : length(udds_data)-1, val_trips) ;

        W_total = [];
        y_total = [];
 
        for s = train_trips % 검증/학습 데이터 셋이 정해지면 1개 folds에 대해, W_total, y_total 계산 
            t = udds_data(s).t;
            dt = [t(1); diff(t)];
            I = udds_data(s).I;
            V = udds_data(s).V;
            SOC = udds_data(s).SOC; 

            [~, ~, ~, ~ , W_aug, y_aug, ~] = DRT_estimation_aug(t, I, V, lambda, n, dt, dur, SOC, soc_values, ocv_values);

            W_total = [W_total; W_aug]; % W 행렬 이어 붙이기 
            y_total = [y_total; y_aug]; % y 행렬 이어 붙이기 
            
        end

        [gamma_total,R0_total] =  DRT_estimation_aug_with_Wy(W_total, y_total, lambda); % 이어 붙인 W,y로 gamma_total 계산

        for j = val_trips
            t = udds_data(j).t;
            dt = [t(1); diff(t)];
            I = udds_data(j).I;
            V = udds_data(j).V;
            SOC = udds_data(j).SOC; 
            j
            [~, ~, ~, ~, W_val, ~, OCV] = DRT_estimation_aug(t, I, V, lambda, n, dt, dur, SOC, soc_values, ocv_values);
            V_est = OCV + W_val * [gamma_total; R0_total];

            error = sum((V - V_est).^2);
            CVE = CVE + error;
          
        end

    end
    
    CVE_total(m) = CVE; % lambda 후보군에 해당하는 CVE 저장 
    fprintf('Lambda: %.2e, CVE: %.4f\n', lambda, CVE_total(m));
end

[~, optimal_idx] = min(CVE_total);
optimal_lambda = lambda_grids(optimal_idx);


%% 5. Plot (CVE vs lambda)

figure;
semilogx(lambda_grids, CVE_total, 'b-', 'LineWidth', 1.5); hold on;
semilogx(optimal_lambda, CVE_total(optimal_idx), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('\lambda', 'FontSize', labelFontSize);
ylabel('CVE', 'FontSize', labelFontSize);
title('CVE vs \lambda ', 'FontSize', titleFontSize);
grid on;
legend({'CVE', ['Optimal \lambda = ', num2str(optimal_lambda, '%.2e')]}, 'Location', 'best');
hold off;


%% function 


% (W,Y 주어졌을때 gamma 해 구하기)
function [gamma_est,R0_est] = DRT_estimation_aug_with_Wy(W_total, y_total, lambda_hat)
    W_total_n = size(W_total, 2) - 1; % Number of gamma parameters
    
    L = zeros(W_total_n-1, W_total_n);
    for i = 1:W_total_n-1
        L(i, i) = -1;
        L(i, i+1) = 1;
    end

    L_aug = [L, zeros(W_total_n-1, 1)]; % No regularization on R0_est

    % Set up the quadratic programming problem
    H = 2 * (W_total' * W_total + lambda_hat * (L_aug' * L_aug));
    f = -2 * W_total' * y_total;

    % Inequality constraints: params >= 0
    A_ineq = -eye(W_total_n + 1);
    b_ineq = zeros(W_total_n + 1, 1);

    % Solve the quadratic programming problem
    options = optimoptions('quadprog', 'Display', 'off');
    params = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

    gamma_est = params(1:end-1);
    R0_est = params(end);
end







