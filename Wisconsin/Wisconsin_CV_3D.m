clear; clc;  close all;

%% 0. 폰트 크기 및 색상 매트릭스 설정
% 폰트 크기 설정
axisFontSize = 14;      % 축 번호 크기
titleFontSize = 16;     % 제목 폰트 크기
legendFontSize = 12;    % 범례 폰트 크기
labelFontSize = 14;     % xlabel 및 ylabel 폰트 크기

% 색상 매트릭스 설정
c_mat = lines(9);  % 9개의 고유한 색상 정의

% 1. 데이터 로드
% UDDS 주행 데이터 로드
load('udds_data.mat');  % 'udds_data' 구조체 로드

% SOC-OCV 데이터 로드
load('soc_ocv.mat', 'soc_ocv');
soc_values = soc_ocv(:, 1);  % SOC 값
ocv_values = soc_ocv(:, 2);  % OCV 값

%% 2. 파라미터 설정

n = 201;
dur = 1370; % [초]
SOC_begin = 0.9907; % 초기 SOC

lambda_grids = logspace(-10, -1, 10);  
num_lambdas = length(lambda_grids);

% Q_batt 그리드 설정
Q_batt_grids = [2.77 ,2.79,2.81, 2.83];%linspace(2.7, 3.1, 20); % [Ah]
num_Q_batt = length(Q_batt_grids);

%% 3. Cross-Validation 루프

validation_combinations = nchoosek(1 : length(udds_data)-1, 2); % 마지막 17번째 데이터는 시간 부족으로 CV에 참여하지 않음
num_folds = size(validation_combinations, 1);
CVE_total = zeros(num_lambdas, num_Q_batt);

for q = 1:num_Q_batt
    Q_batt = Q_batt_grids(q);
    
    % 전체 트립에 대해 SOC 계산 (OCV 업데이트 시 필요)
    
    for u = 1:length(udds_data)
        t = udds_data(u).t;
        dt = [t(1); diff(t)];
        I = udds_data(u).I;
        udds_data(u).SOC = SOC_begin + cumtrapz(t, I) / (Q_batt * 3600);
        SOC_begin = udds_data(u).SOC(end);
    end
    
    for m = 1 : num_lambdas  % 모든 lambda에 대해 루프
        lambda = lambda_grids(m);
        CVE = 0; 
        
        for f = 1 : num_folds % 각 lambda에 대해 모든 폴드에 대해 루프
            val_trips = validation_combinations(f,:);
            train_trips = setdiff(1 : length(udds_data)-1, val_trips);

            W_total = [];
            y_total = [];
     
            for s = train_trips % 학습 데이터에 대해 W_total, y_total 계산
                t = udds_data(s).t;
                dt = [t(1); diff(t)];
                I = udds_data(s).I;
                V = udds_data(s).V;
                SOC = udds_data(s).SOC; 

                [~, ~, ~, ~, W_aug, y_aug, ~] = DRT_estimation_aug(t, I, V, lambda, n, dt, dur, SOC, soc_values, ocv_values);

                W_total = [W_total; W_aug]; % W 행렬 이어붙이기 
                y_total = [y_total; y_aug]; % y 벡터 이어붙이기 
            end

            [gamma_total, R0_total] = DRT_estimation_with_Wy(W_total, y_total, lambda); % 이어붙인 W, y로 gamma_total 계산

            for j = val_trips
                t = udds_data(j).t;
                dt = [t(1); diff(t)];
                I = udds_data(j).I;
                V = udds_data(j).V;
                SOC = udds_data(j).SOC; 

                [~, ~, ~, ~, W_val, ~, OCV] = DRT_estimation_aug(t, I, V, lambda, n, dt, dur, SOC, soc_values, ocv_values);
                V_est = OCV + W_val * [gamma_total; R0_total];

                error = sum((V - V_est).^2);
                CVE = CVE + error;
            end
        end

        CVE_total(m, q) = CVE; % 현재 lambda와 Q_batt에 해당하는 CVE 저장 
        fprintf('Lambda: %.2e, Q_batt: %.4f Ah, CVE: %.4f\n', lambda, Q_batt, CVE_total(m, q));
    end
end

% 최적의 lambda와 Q_batt 찾기
[min_CVE, idx] = min(CVE_total(:));
[optimal_m, optimal_q] = ind2sub(size(CVE_total), idx);
optimal_lambda = lambda_grids(optimal_m);
optimal_Q_batt = Q_batt_grids(optimal_q);
fprintf('Optimal Lambda: %.2e, Optimal Q_batt: %.4f Ah, Minimum CVE: %.4f\n', optimal_lambda, optimal_Q_batt, min_CVE);

%% 5. 그래프 그리기 (CVE vs lambda and Q_batt)

figure;
[X, Y] = meshgrid(lambda_grids, Q_batt_grids);
surf(X, Y, CVE_total'); % CVE_total의 전치로 올바른 방향으로 그리기
xlabel('\lambda', 'FontSize', labelFontSize);
ylabel('Q_{batt} [Ah]', 'FontSize', labelFontSize);
zlabel('CVE', 'FontSize', labelFontSize);
title('CVE vs \lambda and Q_{batt}', 'FontSize', titleFontSize);
grid on;
colorbar;
hold on;
% 최적의 점 표시
plot3(optimal_lambda, optimal_Q_batt, min_CVE, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
legend({'CVE Surface', 'Optimal Point'}, 'Location', 'best');
hold off;

%% 함수 정의

% (W, Y 주어졌을 때 gamma와 R0 추정)
function [gamma_total, R0_total] = DRT_estimation_with_Wy(W_total, y_total, lambda)
    W_total_n = size(W_total, 2) - 1; % gamma 파라미터의 수
    
    L = zeros(W_total_n-1, W_total_n);
    for i = 1:W_total_n-1
        L(i, i) = -1;
        L(i, i+1) = 1;
    end

    L_aug = [L, zeros(W_total_n-1, 1)]; % R0_est에 대한 정규화 없음

    % 이차 프로그래밍 문제 설정
    H = 2 * (W_total' * W_total + lambda * (L_aug' * L_aug));
    f = -2 * W_total' * y_total;

    % 부등식 제약 조건: 파라미터 >= 0
    A_ineq = -eye(W_total_n + 1);
    b_ineq = zeros(W_total_n + 1, 1);

    % 이차 프로그래밍 문제 해결
    options = optimoptions('quadprog', 'Display', 'off');
    params = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

    gamma_total = params(1:end-1);
    R0_total = params(end);
end

