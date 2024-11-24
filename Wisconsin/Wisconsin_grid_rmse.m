clear; clc; close all;

%% 0. 폰트 크기 및 색상 매트릭스 설정
% Font size settings
axisFontSize = 14;      % 축의 숫자 크기
titleFontSize = 16;     % 제목의 폰트 크기
legendFontSize = 12;    % 범례의 폰트 크기
labelFontSize = 14;     % xlabel 및 ylabel의 폰트 크기

% Color matrix 설정
c_mat = lines(9);  % 9개의 고유한 색상 정의

%% 1. 데이터 로드
% UDDS 주행 데이터를 로드합니다.
load('udds_data.mat');  % 'udds_data' 구조체를 로드합니다.

% SOC-OCV 데이터를 로드합니다.
load('soc_ocv.mat', 'soc_ocv');
soc_values = soc_ocv(:, 1);  % SOC 값
ocv_values = soc_ocv(:, 2);  % OCV 값

%% 2. Parameter 설정

n = 201;
dur = 1370; % [sec]
SOC_begin_initial = 0.9907 ; % 초기 SOC

% lambda_hat 그리드 설정
lambda_grids = logspace(-10, 1, 20);   
num_lambdas = length(lambda_grids);

% Q_batt 그리드 설정
Q_batt_grids = linspace(2.61, 3, 20); % [Ah] 
num_Q_batt = length(Q_batt_grids);

%% 3. RMSE 계산 및 시각화

num_trips = length(udds_data);

% RMSE 저장을 위한 매트릭스 초기화
RMSE = zeros(num_lambdas, num_Q_batt);

for lambda_index = 1:num_lambdas
    lambda_hat = lambda_grids(lambda_index);
    fprintf('Processing lambda_grid %d/%d...\n', lambda_index, num_lambdas);
    
    for Q_index = 1:num_Q_batt
        Q_batt = Q_batt_grids(Q_index);
        total_RMSE = 0;
        SOC_begin = SOC_begin_initial;  % 각 조합마다 초기 SOC로 리셋
        
        for s = 1:num_trips
            % DRT_estimation_aug input 
            t = udds_data(s).t;    % 시간 벡터 [초]
            I = udds_data(s).I;    % 전류 벡터 [A]
            V = udds_data(s).V;    % 실제 전압 벡터 [V]
            dt = [t(1); diff(t)];  % 첫 번째 dt는 t(1)으로 설정
            SOC = SOC_begin + cumtrapz(t, I) / (Q_batt * 3600); % SOC 계산
            SOC_all{s} = SOC;  % SOC 저장 (셀 배열 사용)
            
            % DRT_estimation_aug 함수 호출
            [gamma_est, R0_est, V_est , theta_discrete , W, ~, ~] = DRT_estimation_aug(t, I, V, lambda_hat, n, dt, dur, SOC, soc_values, ocv_values);
            
            % RMSE 계산
            RMSE_trip = sqrt(mean((V_est - V).^2));
            total_RMSE = total_RMSE + RMSE_trip;
            
            % SOC 업데이트 
            SOC_begin = SOC(end);
        end
        
        % 총 RMSE 저장
        RMSE(lambda_index, Q_index) = total_RMSE;
    end
end

%% 4. RMSE 시각화

[Q_batt_grid, lambda_hat_grid] = meshgrid(Q_batt_grids, lambda_grids);

% 최소 RMSE와 그 위치 찾기
[min_RMSE, idx] = min(RMSE(:));
[opt_lambda_idx, opt_Q_idx] = ind2sub(size(RMSE), idx);
opt_lambda_hat = lambda_grids(opt_lambda_idx);
opt_Q_batt = Q_batt_grids(opt_Q_idx);

figure;
surf(Q_batt_grid, lambda_hat_grid, RMSE);
hold on;

% 최적의 조합에 빨간색 점 추가
h_opt_point = plot3(opt_Q_batt, opt_lambda_hat, min_RMSE, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

xlabel('Q_{batt} [Ah]', 'FontSize', labelFontSize);
ylabel('\lambda_{hat}', 'FontSize', labelFontSize);
zlabel('Total RMSE Voltage', 'FontSize', labelFontSize);
title('RMSE over Grid of Q_{batt} and \lambda_{grid}', 'FontSize', titleFontSize);
set(gca, 'YScale', 'log');    % lambda_hat이 logspace로 설정되었으므로
colorbar;  
grid on;

% 범례에 최적의 값 표시를 위한 더미 플롯 생성
h_opt_Q = plot(NaN, NaN, 'LineStyle', 'none', 'Marker', 'none', 'DisplayName', sprintf('Optimal Q_{batt} = %.4f Ah', opt_Q_batt));
h_opt_lambda = plot(NaN, NaN, 'LineStyle', 'none', 'Marker', 'none', 'DisplayName', sprintf('Optimal \\lambda_{grid} = %.2e', opt_lambda_hat));

% 범례 생성 (최적의 값만 표시)
legend([h_opt_Q, h_opt_lambda], 'Location', 'best');

hold off;