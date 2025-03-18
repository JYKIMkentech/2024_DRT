clear; clc; close all;

%% 0. 폰트 크기 및 색상 매트릭스 설정
% Font size settings
axisFontSize = 14;      % 축의 숫자 크기
titleFontSize = 16;     % 제목의 폰트 크기
legendFontSize = 12;    % 범례의 폰트 크기
labelFontSize = 14;     % xlabel 및 ylabel의 폰트 크기

% 교수님이 지정하신 10가지 색상 팔레트
% 1:  [0.00000  0.45098  0.76078]  (파랑)
% 2:  [0.93725  0.75294  0.00000]  (노랑)
% 3:  [0.80392  0.32549  0.29803]  (빨강)
% 4:  [0.12549  0.52157  0.30588]  (초록)
% 5:  [0.57255  0.36863  0.62353]  (보라)
% 6:  [0.88235  0.52941  0.15294]  (주황)
% 7:  [0.30196  0.73333  0.83529]  (연한 파랑)
% 8:  [0.93333  0.29803  0.59216]  (핑크)
% 9:  [0.49412  0.38039  0.28235]  (갈색)
% 10: [0.45490  0.46275  0.47059]  (회색)
c_mat = [
    0.00000  0.45098  0.76078;  % #1 파랑
    0.93725  0.75294  0.00000;  % #2 노랑
    0.80392  0.32549  0.29803;  % #3 빨강
    0.12549  0.52157  0.30588;  % #4 초록
    0.57255  0.36863  0.62353;  % #5 보라
    0.88235  0.52941  0.15294;  % #6 주황
    0.30196  0.73333  0.83529;  % #7 연한 파랑
    0.93333  0.29803  0.59216;  % #8 핑크
    0.49412  0.38039  0.28235;  % #9 갈색
    0.45490  0.46275  0.47059   % #10 회색
];

%% 1. 데이터 로드
load('udds_data.mat');  % 'udds_data' 구조체를 로드합니다.
load('soc_ocv.mat', 'soc_ocv');
soc_values = soc_ocv(:, 1);  % SOC 값
ocv_values = soc_ocv(:, 2);  % OCV 값

%% 2. Parameter 설정
n = 201;
dur = 1370; % [sec]
SOC_begin = 0.9907; 
Q_batt = 2.7742; % [Ah]
lambda_hat = 0.358;

%% 3. 각 trip에 대한 DRT 추정 (Quadprog 사용)
num_trips = length(udds_data);

% 결과 저장을 위한 배열 사전 할당
gamma_est_all = zeros(num_trips, n);  % 모든 트립에 대해
R0_est_all = zeros(num_trips, 1);
V_est_all = cell(num_trips, 1); 
SOC_all = cell(num_trips, 1);   
SOC_mid_all = zeros(num_trips,1);

for s = 1:num_trips-1
    fprintf('Processing Trip %d/%d...\n', s, num_trips);
    
    % DRT_estimation_aug input 
    t = udds_data(s).t;    % 시간 벡터 [초]
    I = udds_data(s).I;    % 전류 벡터 [A]
    V = udds_data(s).V;    % 전압 벡터 [V]
     % 정규화 파라미터
    dt = [t(1); diff(t)];  
    SOC = SOC_begin + cumtrapz(t, I) / (Q_batt * 3600); % SOC 계산
    SOC_all{s} = SOC;  
    SOC_mid_all(s) = mean(SOC);

    [gamma_est, R0_est, V_est , theta_discrete , W, ~, ~] = ...
        DRT_estimation_aug(t, I, V, lambda_hat, n, dt, dur, SOC, soc_values, ocv_values);
    
    gamma_est_all(s, :) = gamma_est';
    R0_est_all(s) = R0_est;
    V_est_all{s} = V_est;
    
    % SOC 업데이트 
    SOC_begin = SOC(end);

    %% (1) 전류 / 전압 / 추정 전압 (Figure)
    figure('Name', ['Trip ', num2str(s), ' - Voltage and Current'], ...
           'NumberTitle', 'off', 'Units','normalized', 'Position',[0.05, 0.55, 0.4, 0.35]);

    % 왼쪽 Y축: Voltage (빨강 #3), Estimated Voltage (초록 #4)
    yyaxis left
    plot(t, V, 'Color', c_mat(3, :), 'LineWidth', 3, 'DisplayName', 'Measured Voltage');
    hold on;
    plot(t, V_est, '--', 'Color', c_mat(4, :), 'LineWidth', 3, 'DisplayName', 'Estimated Voltage');
    ylabel('Voltage [V]', 'FontSize', labelFontSize);
    set(gca, 'YColor', c_mat(3, :));  % 왼쪽 Y축 색상(빨강)

    % 오른쪽 Y축: Current (파랑 #1)
    yyaxis right
    plot(t, I, '-', 'Color', c_mat(1, :), 'LineWidth', 3, 'DisplayName', 'Current');
    ylabel('Current [A]', 'FontSize', labelFontSize);
    set(gca, 'YColor', c_mat(1, :));  % 오른쪽 Y축 색상(파랑)

    xlabel('Time [s]', 'FontSize', labelFontSize);
    title(sprintf('Trip %d: Voltage and Current', s), 'FontSize', titleFontSize);
    legend('FontSize', legendFontSize, 'Location','best');
    set(gca, 'FontSize', axisFontSize);
    grid on;
    hold off;

    %% (2) DRT (theta vs gamma) (Figure)
    figure('Name', ['Trip ', num2str(s), ' - DRT'], ...
           'NumberTitle', 'off', 'Units','normalized', 'Position',[0.55, 0.55, 0.4, 0.35]);

    plot(theta_discrete, gamma_est, '-', 'Color', c_mat(1, :) , 'LineWidth', 3);
    xlabel('\theta = ln(\tau [s])', 'FontSize', labelFontSize)
    ylabel('\gamma [\Omega]', 'FontSize', labelFontSize);
    title(sprintf('Trip %d: DRT', s), 'FontSize', titleFontSize);
    set(gca, 'FontSize', axisFontSize);
    grid on; 
    hold on;

    % R0 값을 그림 내부에 표시 
    str_R0 = sprintf('$R_0 = %.1e\\ \\Omega$', R0_est_all(s));
    x_limits = xlim;
    y_limits = ylim;
    text_position_x = x_limits(1) + 0.05 * (x_limits(2) - x_limits(1));
    text_position_y = y_limits(2) - 0.05 * (y_limits(2) - y_limits(1));
    text(text_position_x, text_position_y, str_R0, ...
         'FontSize', labelFontSize, 'Interpreter', 'latex');
    hold off;
end

%% 4. 3D DRT 플롯
% SOC_mid_all을 색상 매핑을 위해 정규화
soc_min = min(SOC_mid_all);
soc_max = max(SOC_mid_all);
soc_normalized = (SOC_mid_all - soc_min) / (soc_max - soc_min);

% 사용할 컬러맵 선택 (jet)
colormap_choice = jet;  
num_colors = size(colormap_choice, 1);
colors = interp1(linspace(0, 1, num_colors), colormap_choice, soc_normalized);

figure('Name','3D DRT','NumberTitle','off','Units','normalized','Position',[0.15, 0.05, 0.7, 0.4]);
hold on;
grid on;

for s = 1:num_trips-1
    x = SOC_mid_all(s) * ones(size(theta_discrete(:)));
    y = theta_discrete(:);
    z = gamma_est_all(s, :)';
    plot3(x, y, z, 'Color', colors(s, :), 'LineWidth', 1.5);
end

xlabel('SOC', 'FontSize', labelFontSize);
ylabel('\theta = ln(\tau [s])', 'FontSize', labelFontSize);
zlabel('\gamma [\Omega]', 'FontSize', labelFontSize);
title('Gamma Estimates vs. \theta and SOC', 'FontSize', titleFontSize);
set(gca, 'FontSize', axisFontSize);
zlim([0, 1.5]);         % 요청하신 z축 범위
view(135, 30);          % 시각화 각도 조정

colormap(colormap_choice);
c = colorbar;
c.Label.String = 'SOC';
c.Label.FontSize = labelFontSize;
c.Ticks = linspace(0, 1, 5);
c.TickLabels = arrayfun(@(x) sprintf('%.3f', x), ...
                        linspace(soc_min, soc_max, 5), ...
                        'UniformOutput', false);

hold off;

%% 5. 결과 저장
save('gamma_est_all.mat', 'gamma_est_all', 'SOC_mid_all');
save('theta_discrete.mat', 'theta_discrete');
save('R0_est_all.mat', 'R0_est_all');
save('udds_data.mat', 'udds_data');












