%% demo_1RC_2RC_fit.m
clc; clear; close all;

%% 1) 색상 팔레트 정의
p_colors = [
    0.00000, 0.45098, 0.76078;  % #1 (Blue)
    0.93725, 0.75294, 0.00000;  % #2 (Yellow-ish)
    0.80392, 0.32549, 0.29803;  % #3 (Red)
    0.12549, 0.52157, 0.30588;  % #4 (Green-ish)
    0.57255, 0.36863, 0.62353;  % #5
    0.88235, 0.52941, 0.15294;  % #6
    0.30196, 0.73333, 0.83529;  % #7
    0.93333, 0.29803, 0.59216;  % #8
    0.49412, 0.38039, 0.28235;  % #9
    0.45490, 0.46275, 0.47059   % #10
];

%% 2) 데이터 불러오기
load('udds_data.mat');  % 예: udds_data(1).t, I, V, SOC
load('soc_ocv.mat');    % 예: soc_ocv(:,1)=SOC, soc_ocv(:,2)=OCV

% 첫 번째 trip 데이터
t       = udds_data(1).t;
I       = udds_data(1).I;
V_meas  = udds_data(1).V;
SOC     = udds_data(1).SOC;

%% 3) 1RC 모델 파라미터 식별
%    x_1rc = [R0, R1, C1]
x0_1rc   = [0.02; 0.01; 50];  % 초기값 예시
lb_1rc   = [0; 0; 0];
ub_1rc   = [];
options  = optimoptions('fmincon','Display','iter','Algorithm','sqp');

[x_opt_1rc, fval_1rc] = fmincon(@(x) cost_1rc(x, t, I, V_meas, SOC, soc_ocv), ...
                                x0_1rc, [], [], [], [], lb_1rc, ub_1rc, [], options);

R0_1rc = x_opt_1rc(1);
R1_1rc = x_opt_1rc(2);
C1_1rc = x_opt_1rc(3);

fprintf('=== [1RC] 최적화 결과 ===\n');
fprintf('R0 = %.6f, R1 = %.6f, C1 = %.6f,  RMSE= %.6f\n', ...
         R0_1rc, R1_1rc, C1_1rc, fval_1rc);

% 1RC 모델 전압 시뮬레이션
V_model_1rc = ECM_1RC(x_opt_1rc, t, I, SOC, soc_ocv);

%% 4) 2RC 모델 파라미터 식별
%    x_2rc = [R0, R1, C1, R2, C2]
x0_2rc  = [0.02; 0.01; 50; 0.01; 50];  % 초기값 예시
lb_2rc  = [0; 0; 0; 0; 0];
ub_2rc  = [];

[x_opt_2rc, fval_2rc] = fmincon(@(x) cost_2rc(x, t, I, V_meas, SOC, soc_ocv), ...
                                x0_2rc, [], [], [], [], lb_2rc, ub_2rc, [], options);

R0_2rc = x_opt_2rc(1);
R1_2rc = x_opt_2rc(2);
C1_2rc = x_opt_2rc(3);
R2_2rc = x_opt_2rc(4);
C2_2rc = x_opt_2rc(5);

fprintf('=== [2RC] 최적화 결과 ===\n');
fprintf('R0 = %.6f, R1 = %.6f, C1 = %.6f, R2 = %.6f, C2 = %.6f,  RMSE= %.6f\n', ...
         R0_2rc, R1_2rc, C1_2rc, R2_2rc, C2_2rc, fval_2rc);

% 2RC 모델 전압 시뮬레이션
V_model_2rc = ECM_2RC(x_opt_2rc, t, I, SOC, soc_ocv);

%% 5) 그림 4개 그리기

% FIGURE 1 : 1RC 모델 전압 비교
figure(1); hold on; grid on;
plot(t, V_meas,     'LineWidth', 2, 'Color', p_colors(1,:), ...
     'DisplayName','Measured V');
plot(t, V_model_1rc,'LineWidth', 2, 'Color', p_colors(3,:), ...
     'DisplayName','1RC Model V');
xlabel('Time (s)', 'FontSize', 12);
ylabel('Voltage (V)', 'FontSize', 12);
title('1RC Model Fitting', 'FontSize', 12);
legend('Location','best');
set(gca, 'FontSize', 12);

% FIGURE 2 : 2RC 모델 전압 비교
figure(2); hold on; grid on;
plot(t, V_meas,     'LineWidth', 2, 'Color', p_colors(1,:), ...
     'DisplayName','Measured V');
plot(t, V_model_2rc,'LineWidth', 2, 'Color', p_colors(4,:), ...
     'DisplayName','2RC Model V');
xlabel('Time (s)', 'FontSize', 12);
ylabel('Voltage (V)', 'FontSize', 12);
title('2RC Model Fitting', 'FontSize', 12);
legend('Location','best');
set(gca, 'FontSize', 12);

% FIGURE 3 : 측정 V, 1RC V, 2RC V 함께 표시
figure(3); hold on; grid on;
plot(t, V_meas,      'LineWidth', 2, 'Color', p_colors(1,:), ...
     'DisplayName','Measured V');
plot(t, V_model_1rc, 'LineWidth', 2, 'Color', p_colors(3,:), ...
     'DisplayName','1RC Model V');
plot(t, V_model_2rc, 'LineWidth', 2, 'Color', p_colors(4,:), ...
     'DisplayName','2RC Model V');
xlabel('Time (s)', 'FontSize', 12);
ylabel('Voltage (V)', 'FontSize', 12);
title('Model Voltage Fitting comparision : 1RC vs 2RC', 'FontSize', 12);
legend('Location','best');
set(gca, 'FontSize', 12);

% FIGURE 4 : 전류(I) 그래프
figure(4); hold on; grid on;
plot(t, I, 'LineWidth', 2, 'Color', p_colors(2,:), ...
     'DisplayName','Current');
xlabel('Time (s)', 'FontSize', 12);
ylabel('Current (A)', 'FontSize', 12);
title('UDDS current Profile ', 'FontSize', 12);
legend('Location','best');
set(gca, 'FontSize', 12);

%% 6) Residual(잔차) 계산 및 비교 (Figure 5)
resid_1rc = V_meas - V_model_1rc;
resid_2rc = V_meas - V_model_2rc;

figure(5); hold on; grid on;
plot(t, resid_1rc, 'LineWidth', 2, 'Color', p_colors(3,:), ...
     'DisplayName','1RC Residual');
plot(t, resid_2rc, 'LineWidth', 2, 'Color', p_colors(4,:), ...
     'DisplayName','2RC Residual');
xlabel('Time (s)', 'FontSize', 12);
ylabel('Residual (V)', 'FontSize', 12);
title('Model Fitting residual : 1RC vs 2RC ', 'FontSize', 12);
xlim([10 70])
legend('Location','best');
set(gca, 'FontSize', 12);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% -------------------- 1RC 모델용 cost/시뮬레이션 함수 --------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cost = cost_1rc(x, t, I, V_meas, SOC, soc_ocv)
    V_model = ECM_1RC(x, t, I, SOC, soc_ocv);
    cost = sqrt(mean((V_meas - V_model).^2));
end

function V_model = ECM_1RC(x, t, I, SOC, soc_ocv)
    % x(1)=R0, x(2)=R1, x(3)=C1
    % 1RC 모델:
    %   U1(k+1) = alpha1*U1(k) + R1*(1 - alpha1)*I(k)
    %   V(k+1)  = OCV(k+1) + R0*I(k+1) + U1(k+1)
    %   alpha1  = exp(-dt/(R1*C1))
    R0  = x(1);
    R1  = x(2);
    C1  = x(3);

    N = length(t);
    V_model = zeros(N,1);
    U1      = zeros(N,1);

    % 초기 조건
    U1(1) = 0;  
    OCV_first  = interp1(soc_ocv(:,1), soc_ocv(:,2), SOC(1), 'linear','extrap');
    V_model(1) = OCV_first + R0*I(1) + U1(1);

    for k = 1 : N-1
        dt     = t(k+1) - t(k);
        alpha1 = exp(-dt/(R1*C1));

        U1(k+1)      = alpha1*U1(k) + R1*(1 - alpha1)*I(k);
        OCV_next     = interp1(soc_ocv(:,1), soc_ocv(:,2), SOC(k+1), 'linear','extrap');
        V_model(k+1) = OCV_next + R0*I(k+1) + U1(k+1);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% -------------------- 2RC 모델용 cost/시뮬레이션 함수 --------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cost = cost_2rc(x, t, I, V_meas, SOC, soc_ocv)
    V_model = ECM_2RC(x, t, I, SOC, soc_ocv);
    cost = sqrt(mean((V_meas - V_model).^2));
end

function V_model = ECM_2RC(x, t, I, SOC, soc_ocv)
    % x(1)=R0, x(2)=R1, x(3)=C1, x(4)=R2, x(5)=C2
    % 2RC 모델:
    %   U1(k+1) = alpha1*U1(k) + R1*(1 - alpha1)*I(k)
    %   U2(k+1) = alpha2*U2(k) + R2*(1 - alpha2)*I(k)
    %   V(k+1)  = OCV(k+1) + R0*I(k+1) + U1(k+1) + U2(k+1)
    %   alpha1  = exp(-dt/(R1*C1)), alpha2 = exp(-dt/(R2*C2))

    R0  = x(1);
    R1  = x(2);
    C1  = x(3);
    R2  = x(4);
    C2  = x(5);

    N = length(t);
    V_model = zeros(N,1);
    U1      = zeros(N,1);
    U2      = zeros(N,1);

    % 초기 조건
    U1(1) = 0;
    U2(1) = 0;
    OCV_first  = interp1(soc_ocv(:,1), soc_ocv(:,2), SOC(1), 'linear','extrap');
    V_model(1) = OCV_first + R0*I(1) + U1(1) + U2(1);

    for k = 1 : N-1
        dt      = t(k+1) - t(k);
        alpha1  = exp(-dt/(R1*C1));
        alpha2  = exp(-dt/(R2*C2));

        U1(k+1) = alpha1*U1(k) + R1*(1 - alpha1)*I(k);
        U2(k+1) = alpha2*U2(k) + R2*(1 - alpha2)*I(k);

        OCV_next    = interp1(soc_ocv(:,1), soc_ocv(:,2), SOC(k+1), 'linear','extrap');
        V_model(k+1)= OCV_next + R0*I(k+1) + U1(k+1) + U2(k+1);
    end
end


