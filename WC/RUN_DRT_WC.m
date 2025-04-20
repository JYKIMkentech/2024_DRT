clc;clear;close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run_DRT_from_Results.m  (2025‑04‑20)
% -------------------------------------------------------------------------
%  • 입력 : Results.mat (Trip별 [V I t SOC] 저장), 내부에 OCV table 포함
%  • 출력 : γ, R0, V_est, 부트스트랩 5–95% 범위, PNG / MAT 파일
% -------------------------------------------------------------------------

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % θ grid size
tau_max      = 1370;       % dur  [s]
lambda_hat   = 0.05;       % regularisation
Q_batt_Ah    = 5;      % 배터리 용량 (Ah)
num_bs       = 200;        % bootstrap 반복
outDir       = 'DRT_Figures';

if ~exist(outDir,'dir'), mkdir(outDir); end

%% 1) 데이터 로드 ----------------------------------------------------------
load('Results.mat','Results');               % Trip parsing 결과

% OCV table (SOC , V) – 첫 사이클에서 가져옴
idxOCV = find(~cellfun(@isempty,{Results.OCV}), 1, 'first');
soc_ocv = Results(idxOCV).OCV;               % (N_ocv×2)
soc_values = soc_ocv(:,1);   ocv_values = soc_ocv(:,2);

nCycles = numel(Results);

%% 2) 결과 저장 변수 -------------------------------------------------------
gamma_single = {};        % cell{cyc,trip} → (n×1)
gamma_mean   = {};
gamma_low    = {};
gamma_high   = {};
R0_single    = {};
V_est_cell   = {};

%% 3) 메인 루프 -----------------------------------------------------------
for c = 1:nCycles
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d  (index %d/%d) ===\n', cyc, c, nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld)), break; end

        T_trip = Results(c).(fld);            % [V I t SOC]
        V  = T_trip(:,1);   I  = T_trip(:,2);
        t  = T_trip(:,3);   SOC = T_trip(:,4);

        fprintf('  > Trip %d  (N = %d)\n', tripIdx, numel(t));

        % 단일 DRT 추정 ----------------------------------------------------
        [gamma_hat, R0_hat, V_est] = DRT_estimation_aug( ...
                t, I, V, lambda_hat, n, tau_max, ...
                SOC, soc_values, ocv_values);

        % 부트스트랩 -------------------------------------------------------
        SOC_begin = SOC(1);
        gamma_bs = bootstrap_uncertainty_aug_FromResults( ...
                t, I, V, lambda_hat, n, tau_max, ...
                num_bs, SOC_begin, Q_batt_Ah, ...
                soc_values, ocv_values);

        g_mean = mean(gamma_bs,1).';
        g_low  = prctile(gamma_bs,  5, 1).';
        g_high = prctile(gamma_bs, 95, 1).';

        % 저장 --------------------------------------------------------------
        gamma_single{c,tripIdx} = gamma_hat;
        gamma_mean{c,tripIdx}   = g_mean;
        gamma_low{c,tripIdx}    = g_low;
        gamma_high{c,tripIdx}   = g_high;
        R0_single{c,tripIdx}    = R0_hat;
        V_est_cell{c,tripIdx}   = V_est;

        % **** (선택) Trip별 그림 저장 *************************************
        fig = figure('Visible','off');
        yyaxis left
        plot(t,V,'k','LineWidth',1.2); hold on;
        plot(t,V_est,'--','LineWidth',1.2);
        ylabel('Voltage [V]');

        yyaxis right
        plot(t,I,'b','LineWidth',1);
        ylabel('Current [A]');
        title(sprintf('Cycle %d – Trip %d',cyc,tripIdx));
        grid on
        exportgraphics(fig, fullfile(outDir, ...
            sprintf('Volt_curr_cyc%03d_trip%02d.png',cyc,tripIdx)),300);
        close(fig);

        % γ(θ) plot --------------------------------------------------------
        theta = linspace(log(0.1), log(tau_max), n).';
        fig = figure('Visible','off');
        fill([theta; flipud(theta)], ...
             [g_low; flipud(g_high)], ...
             [0.6 0.4 0.8],'FaceAlpha',0.2,'EdgeColor','none'); hold on;
        plot(theta,g_mean,'Color',[0.5 0 0.5],'LineWidth',2);
        xlabel('\theta = ln(τ)');  ylabel('\gamma [\Omega]');
        title(sprintf('γ – Cycle %d, Trip %d',cyc,tripIdx));
        grid on
        exportgraphics(fig, fullfile(outDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png',cyc,tripIdx)),300);
        close(fig);

        tripIdx = tripIdx + 1;
    end
end

%% 4) MAT 저장 -------------------------------------------------------------
save('DRT_gamma_single.mat','gamma_single','R0_single');
save('DRT_gamma_bootstrap.mat','gamma_mean','gamma_low','gamma_high');
disp('Run_DRT_from_Results: complete.');
