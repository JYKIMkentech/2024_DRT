clc; clear; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run_DRT_from_Results.m
% -------------------------------------------------------------------------
%  Input  : Results.mat  (Trip‑wise [V  I  t_abs  tRel  SOC])
%  Output : γ̂, R0̂, V_est, bootstrap 5–95 % bands, RMSE, PNG & MAT files
%
%  2025‑04‑21 rev‑3
%    • Results.Trips_* = 5‑col format (V I t_abs tRel SOC)
%    • 전압+전류 그림: 더 이상 x‑lim 없음 (전체 구간 표시)
%    • 전압 비교 전용 그림 추가 (0‑100 s, 전류 미표시)
%    • ▶ Trip‑별 전압 RMSE 계산·저장 기능 추가
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% USER SETTINGS ----------------------------------------------------------
n            = 201;         % theta grid size
tau_max      = 20000;       % τ_max [s]
lambda_hat   = 0.5;         % ℓ₂‑regularisation
Q_batt_Ah    = 5;           % battery capacity [Ah]
num_bs       = 100;         % bootstrap repeats
outDir       = 'DRT_Figures';

if ~exist(outDir,'dir'), mkdir(outDir); end

%% 1) load data -----------------------------------------------------------
load('Results.mat','Results');

soc_ocv    = Results(1).OCV;      % [SoC  V]
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);
nCycles    = numel(Results);

%% 2) containers ----------------------------------------------------------
gamma_single = {};
gamma_mean   = {};
gamma_low    = {};
gamma_high   = {};
R0_single    = {};
V_est_cell   = {};
RMSE_V       = {};            % ▶ Trip‑별 전압 RMSE [V]

%% 3) main loop -----------------------------------------------------------
for c = 1 % 1: nCycles           % 필요 시 1:nCycles 전체 수행
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d (index %d/%d) ===\n',cyc,c,nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld)), break; end

        Temp = Results(c).(fld);           % [V I t tRel SOC]
        V    = Temp(:,1);
        I    = Temp(:,2);
        t    = Temp(:,3);                  % 절대시간
        tRel = Temp(:,4);                  % 0 s 기준 상대시간
        SOC  = Temp(:,5);

        fprintf('  > Trip %d  (N = %d)\n',tripIdx,numel(t));

        % ------- single‑run DRT ----------------------------------------
        [gamma_hat,R0_hat,V_est] = DRT_estimation_aug( ...
            tRel, I, V, lambda_hat, n, tau_max, ...
            SOC, soc_values, ocv_values);

        % ------- RMSE 계산 ---------------------------------------------
        rmse = sqrt( mean( (V - V_est).^2 ) );
        fprintf('      RMSE(V) = %.4f V\n', rmse);
        RMSE_V{c,tripIdx} = rmse;          % ▶ 저장

        % ------- bootstrap ---------------------------------------------
        SOC_begin = SOC(1);
        gamma_bs  = bootstrap_uncertainty_aug_FromResults( ...
            tRel, I, V, lambda_hat, n, tau_max, num_bs, ...
            SOC_begin, Q_batt_Ah, soc_values, ocv_values);

        g_mean = mean(gamma_bs,1).';
        g_low  = prctile(gamma_bs,  5,1).';
        g_high = prctile(gamma_bs, 95,1).';

        % ------- store --------------------------------------------------
        gamma_single{c,tripIdx} = gamma_hat;
        gamma_mean{c,tripIdx}   = g_mean;
        gamma_low{c,tripIdx}    = g_low;
        gamma_high{c,tripIdx}   = g_high;
        R0_single{c,tripIdx}    = R0_hat;
        V_est_cell{c,tripIdx}   = V_est;

        % ------- 전압 + 전류 (전체 구간) --------------------------------
        figVC = figure;
        yyaxis left
        plot(t, V,     'k',  'LineWidth',1.2); hold on;
        plot(t, V_est, '--', 'LineWidth',1.2);
        ylabel('Voltage [V]');
        yyaxis right
        plot(t, I, 'b', 'LineWidth',1);
        ylabel('Current [A]');
        title(sprintf('Cycle %d – Trip %d',cyc,tripIdx));
        grid on
        legend({'V_{meas}','V_{est}','I'},'Location','best');
        exportgraphics(figVC, fullfile(outDir, ...
            sprintf('Volt_curr_ALL_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);

        % ------- 전압 비교 (0‑100 s) ------------------------------------
        figVZ = figure;
        plot(tRel, V,     'k',  'LineWidth',1.2); hold on;
        plot(tRel, V_est, '--', 'LineWidth',1.2);
        xlabel('Time [s]');
        ylabel('Voltage [V]');
        title(sprintf('Voltage (0–100 s) – Cycle %d, Trip %d',cyc,tripIdx));
        grid on
        xlim([0 100]);
        legend({'V_{meas}','V_{est}'},'Location','best');
        exportgraphics(figVZ, fullfile(outDir, ...
            sprintf('Volt_zoom_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);

        % ------- γ(θ) plot ---------------------------------------------
        theta = linspace(log(0.1), log(tau_max), n).';
        figG = figure;
        fill([theta; flipud(theta)], ...
             [g_low;  flipud(g_high)], ...
             [0.6 0.4 0.8], 'FaceAlpha',0.2, 'EdgeColor','none'); hold on;
        plot(theta, g_mean, 'Color',[0.5 0 0.5], 'LineWidth',2);
        xlabel('\theta = ln(\tau [s])');
        ylabel('\gamma [\Omega]');
        title(sprintf('\\gamma – Cycle %d, Trip %d',cyc,tripIdx));
        grid on
        exportgraphics(figG, fullfile(outDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);

                  
        tripIdx = tripIdx + 1;
    end
end

%% 4) save MAT files ------------------------------------------------------
save('DRT_gamma_single.mat',    'gamma_single', 'R0_single', 'RMSE_V');  % ▶
save('DRT_gamma_bootstrap.mat', 'gamma_mean',   'gamma_low', 'gamma_high');

fprintf('\n▶ 완료: 모든 그림과 MAT 파일이 “%s”에 저장되었습니다.\n', outDir);
disp('Run_DRT_from_Results: complete.');


