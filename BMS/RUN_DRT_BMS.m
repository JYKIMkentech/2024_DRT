%% 0. 초기화 및 폰트/색상 설정
clear; clc; close all;

% 폰트, 색상 매트릭스 등은 기존 코드 그대로 쓰시면 됩니다.
axisFontSize   = 14;
titleFontSize  = 16;
legendFontSize = 12;
labelFontSize  = 14;

c_mat = [
    0.00000  0.45098  0.76078;  % 파랑
    0.93725  0.75294  0.00000;  % 노랑
    0.80392  0.32549  0.29803;  % 빨강
    0.12549  0.52157  0.30588;  % 초록
    0.57255  0.36863  0.62353;  % 보라
    0.88235  0.52941  0.15294;  % 주황
    0.30196  0.73333  0.83529;  % 연한 파랑
    0.93333  0.29803  0.59216;  % 핑크
    0.49412  0.38039  0.28235;  % 갈색
    0.45490  0.46275  0.47059   % 회색
];

%% 1. BMS 데이터 로드
%  (예) CSV 파일을 읽어서 time[sec], pack_current[A], pack_voltage[V] 뽑아오기
%  컬럼 순서는 CSV 파일 상태에 맞춰 바꾸세요.
bms_data  = readmatrix('G:\공유 드라이브\Battery Software Lab\Projects\DRT\BMS\bms_01241227999-2023-05-trip-27.csv');
time       = bms_data(:, 1);  % 1열이 time[s]라고 가정
pack_volt  = bms_data(:, 9);  % 9열이 팩 전압[V]라고 가정
pack_curr  = bms_data(:, 10); % 10열이 팩 전류[A]라고 가정

% 만약 BMS SoC가 6번째 열이라면, 그것도 필요하면 불러올 수 있음
% bms_soc  = bms_data(:, 6);  % (예: SOC)

%% 2. OCV 데이터 로드
%  현대파우치셀 OCV 곡선이 들어있는 NE_golden.mat을 불러와서
%  NE_golden.SOC, NE_golden.OCV_golden을 사용할 수 있다고 가정
load('G:\공유 드라이브\BSL-Data\Processed_data\Hyundai_dataset\현대차파우치셀 (rOCV,Crate)\NE_characterization\NE_golden.mat',...
     'NE_golden');

soc_values = NE_golden.SOC/100;          % 예: [37×1 double]
ocv_values = NE_golden.OCV_golden;   % 예: [37×1 double]

%% 3. 파라미터 설정
n          = 201;            % RC 임피던스 소자 수
dur        = 1800;           % tau_max 예시 (원래는 UDDS에서 1370s라 썼지만, BMS 데이터에 맞춰 변경 가능)
lambda_hat = 100;       % 정규화 파라미터 (필요에 맞춰 조정)
Q_batt     = 110.445;         % [Ah] (해당 셀 정격 용량)
SOC_begin  = 0.82;           % 초기 SOC (모르겠으면 BMS_SOC 첫 값으로 대체하거나 추정)

% time 간격 계산
dt = [time(1); diff(time)];

%% 4. SOC 계산 (방법 2가지)
% (방법 A) BMS에 들어있는 SOC를 신뢰한다면 bms_soc을 사용
% (방법 B) 초기 SOC를 잡고, 전류적분으로 SOC를 직접 추정
SOC = SOC_begin - cumtrapz(time, pack_curr)/(Q_batt * 3600);

% 만약 BMS에 SOC 열이 있고, 그걸 쓰고 싶으면 아래처럼 간단히 교체도 가능
% SOC = bms_soc;

%% 5. DRT 추정 실행 (단일 Trip)
[gamma_est, R0_est, V_est, theta_discrete, ~, y, OCV] = ...
    DRT_estimation_aug( ...
        time,       ... % t
        pack_curr,  ... % ik
        pack_volt,  ... % V_sd (실측 팩 전압)
        lambda_hat, ... % regularization
        n,          ... % RC 소자 개수
        dt,         ... % time step
        dur,        ... % tau_max
        SOC,        ... % SOC 벡터
        soc_values, ... % SOC-OCV (x축)
        ocv_values  ... % SOC-OCV (y축)
    );

%% 6. 결과 플롯
% (1) 측정 전압 vs. 추정 전압, 그리고 전류
figure('Name', 'Measured vs. Estimated Voltage (BMS data)', ...
       'NumberTitle','off','Units','normalized','Position',[0.05,0.55,0.4,0.35]);

yyaxis left
plot(time, pack_volt, 'Color', c_mat(3,:), 'LineWidth', 3, 'DisplayName','Measured Voltage');
hold on;
plot(time, V_est, '--', 'Color', c_mat(4,:), 'LineWidth', 3, 'DisplayName','Estimated Voltage');
ylabel('Voltage [V]', 'FontSize', labelFontSize);
set(gca, 'YColor', c_mat(3,:));

yyaxis right
plot(time, pack_curr, '-', 'Color', c_mat(1,:), 'LineWidth', 3, 'DisplayName','Current');
ylabel('Current [A]', 'FontSize', labelFontSize);
set(gca, 'YColor', c_mat(1,:));

xlabel('Time [s]', 'FontSize', labelFontSize);
title('Measured vs. Estimated Voltage (BMS data)', 'FontSize', titleFontSize);
legend('FontSize', legendFontSize, 'Location','best');
set(gca, 'FontSize', axisFontSize);
grid on;
hold off;

% (2) DRT (theta vs gamma)
figure('Name','DRT (BMS data)','NumberTitle','off','Units','normalized','Position',[0.55,0.55,0.4,0.35]);
plot(theta_discrete, gamma_est, '-', 'Color', c_mat(1,:) , 'LineWidth', 3);
xlabel('\theta = ln(\tau [s])', 'FontSize', labelFontSize);
ylabel('\gamma [\Omega]',       'FontSize', labelFontSize);
title('DRT from BMS data',     'FontSize', titleFontSize);
set(gca, 'FontSize', axisFontSize);
grid on; 
hold on;

% R0 값을 그림에 표시
str_R0 = sprintf('$R_0 = %.2e\\,\\Omega$', R0_est);
x_limits = xlim;
y_limits = ylim;
text_position_x = x_limits(1) + 0.05 * (x_limits(2) - x_limits(1));
text_position_y = y_limits(2) - 0.05 * (y_limits(2) - y_limits(1));
text(text_position_x, text_position_y, str_R0, ...
     'FontSize', labelFontSize, 'Interpreter', 'latex');
hold off;
