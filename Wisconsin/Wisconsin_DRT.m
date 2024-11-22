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
SOC_begin = 0.9907 ; % 0.9901;
%soc_begin = interp1(ocv_values, soc_values, udds_data(1).V(1), 'linear', 'extrap');
Q_batt = 2.93; % [Ah]

%% 3. 각 trip에 대한 DRT 추정 (Quadprog 사용)

num_trips = length(udds_data);

% 결과 저장을 위한 배열 사전 할당
gamma_est_all = zeros(num_trips, n);  % 모든 트립에 대해
R0_est_all = zeros(num_trips, 1);
V_est_all = cell(num_trips, 1); % 추정된 전압 저장을 위한 셀 배열
SOC_all = cell(num_trips, 1);   % 각 트립의 SOC 저장을 위한 셀 배열

for s = 1:num_trips
    fprintf('Processing Trip %d/%d...\n', s, num_trips);
    
    % DRT_estimation_aug input 
    t = udds_data(s).t;    % 시간 벡터 [초]
    I = udds_data(s).I;    % 전류 벡터 [A]
    V = udds_data(s).V;    % 전압 벡터 [V]
    lambda_hat = 6e-4;      % 정규화 파라미터
    dt = [t(1); diff(t)];  % 첫 번째 dt는 t(1)으로 설정
    SOC = SOC_begin + cumtrapz(t, I) / (Q_batt * 3600); % 분자 : A * s / 분모 : A * s 
    SOC_all{s} = SOC;  % SOC 저장 (셀 배열 사용)
    
    % DRT_estimation_aug 함수 호출
    [gamma_est, R0_est, V_est , theta_discrete , W, ~, ~] = DRT_estimation_aug(t, I, V, lambda_hat, n, dt, dur, SOC, soc_values, ocv_values);
    
    % 결과 저장
    gamma_est_all(s, :) = gamma_est';
    R0_est_all(s) = R0_est;
    V_est_all{s} = V_est;  % 셀 배열에 저장
    
    % SOC 업데이트 
    SOC_begin = SOC(end);
end

%% Plot

for s = 1:num_trips-15  
    figure;
    
    % True Voltage 플롯
    plot(udds_data(s).t, udds_data(s).V, 'Color', c_mat(1, :), 'LineWidth', 1.5);
    hold on;
    
    % Estimated Voltage 플롯
    plot(udds_data(s).t, V_est_all{s}, '--', 'Color', c_mat(2, :), 'LineWidth', 1.5);
    
    % Current 플롯 추가 (필요 시 주석 해제)
    %plot(udds_data(s).t, udds_data(s).I, '-', 'Color', c_mat(3, :), 'LineWidth', 1.5);
    
    xlabel('Time [s]', 'FontSize', labelFontSize);
    ylabel('Voltage [V]', 'FontSize', labelFontSize);
    title(sprintf('True vs Estimated Voltage for Trip %d', s), 'FontSize', titleFontSize);
    
    % 범례 설정
    legend_entries = {'True Voltage', 'Estimated Voltage'};
    legend(legend_entries, 'FontSize', legendFontSize);
    
    grid on;
    set(gca, 'FontSize', axisFontSize);
    
    % 각 트립의 R0 추정값 출력 (필요 시 주석 해제)
    % fprintf('Estimated R0 for Trip %d: %.4f Ohm\n', s, R0_est_all(s));
end

