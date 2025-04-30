clc; clear; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run_DRT_from_Results.m   (rev-7, 2025-04-23)
% -------------------------------------------------------------------------
%  Input  : PreResults\Results.mat  (Trips_k: m×5 double [V I t tRel SOC])
%  Output : DRTresults.mat  (Trips_k 그대로, + DRTk: n×2 [θ γ̂] )
%           + 그림(전압/전류, 전압확대, γ̂), Trip별 RMSE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % theta grid size
tau_max      = 20000;      % τ_max [s]
lambda_hat   = 1.17;       % ℓ₂ regularisation
Q_batt_Ah    = 5;          % battery capacity [Ah]
num_bs       = 100;        % bootstrap repeats

%% PATHS ------------------------------------------------------------------
rootDir      = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\WC_DRT';
preDir       = fullfile(rootDir,'PreResults');           % Results.mat  위치
drtDir       = fullfile(rootDir,'DRTResults');           % 결과 MAT
figDir       = fullfile(drtDir,'DRT_Figures');           % 그림

if ~exist(drtDir,'dir'), mkdir(drtDir); end
if ~exist(figDir,'dir'), mkdir(figDir); end

%% 1) load data -----------------------------------------------------------
load(fullfile(preDir,'Results.mat'),'Results');           % 원본 구조체

soc_ocv    = Results(1).OCV;              % [SoC  V]
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);
nCycles    = numel(Results);

%% 2) containers ----------------------------------------------------------
gamma_est  = {};          % single-run γ̂ (선택 저장)
RMSE_V     = {};          % Trip별 전압 RMSE [V]

%% 3) main loop -----------------------------------------------------------
for c = 1
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d (index %d/%d) ===\n',cyc,c,nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld)), break; end

        Tmp  = Results(c).(fld);          % [V I t tRel SOC] (m×5)
        V    = Tmp(:,1);  I = Tmp(:,2);
        t    = Tmp(:,3);  tRel = Tmp(:,4);
        SOC  = Tmp(:,5);

        fprintf('  > Trip %d  (N = %d)\n',tripIdx,numel(t));

        % -------- DRT estimation ----------------------------------------
        [g_hat,R0_hat,V_est] = DRT_estimation_aug( ...
            tRel,I,V,lambda_hat,n,tau_max, ...
            SOC,soc_values,ocv_values);

        % -------- RMSE ---------------------------------------------------
        rmse = sqrt(mean((V-V_est).^2));
        RMSE_V{c,tripIdx} = rmse;
        fprintf('      RMSE(V) = %.4f V\n',rmse);

        % -------- store θ & γ̂  ------------------------------------------
        theta = linspace(log(0.1),log(tau_max),n).';
        Results(c).(sprintf('DRT%d',tripIdx)) = [theta, g_hat];  % n×2
        gamma_est{c,tripIdx} = g_hat;                            % (opt)

        % -------- OPTIONAL bootstrap (계산은 하지만 구조체엔 저장 X) ------
        % g_bs = bootstrap_uncertainty_aug_FromResults( ...
        %     tRel,I,V,lambda_hat,n,tau_max,num_bs, ...
        %     SOC(1),Q_batt_Ah,soc_values,ocv_values);
        % g_low = prctile(g_bs,5,1).'; g_high = prctile(g_bs,95,1).';

        % -------- 그림 ----------------------------------------------------
        % (a) 전압+전류 전체
        figVC = figure('Visible','off');
        yyaxis left
        plot(t,V,'k','LineWidth',1.2); hold on
        plot(t,V_est,'--','LineWidth',1.2);
        ylabel('Voltage [V]');
        yyaxis right
        plot(t,I,'b','LineWidth',1);
        ylabel('Current [A]');
        title(sprintf('Cycle %d – Trip %d',cyc,tripIdx));
        legend({'V_{meas}','V_{est}','I'},'Location','best');
        grid on
        exportgraphics(figVC,fullfile(figDir, ...
            sprintf('Volt_curr_ALL_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);
        close(figVC);

        % (b) 전압 비교 0-100 s
        figVZ = figure('Visible','off');
        plot(tRel,V,'k','LineWidth',1.2); hold on
        plot(tRel,V_est,'--','LineWidth',1.2);
        xlabel('Time [s]'); ylabel('Voltage [V]');
        title(sprintf('Voltage (0–100 s) – C%d T%d',cyc,tripIdx));
        grid on; xlim([0 100]);
        legend({'V_{meas}','V_{est}'},'Location','best');
        exportgraphics(figVZ,fullfile(figDir, ...
            sprintf('Volt_zoom_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);
        close(figVZ);

        % (c) γ̂(θ) plot
        figG = figure('Visible','off');
        plot(theta,g_hat,'Color',[0.5 0 0.5],'LineWidth',1.6); grid on
        xlabel('\theta = ln(\tau [s])'); ylabel('\gammâ [\Omega]');
        title(sprintf('\\gammâ – C%d, T%d',cyc,tripIdx));
        exportgraphics(figG,fullfile(figDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);
        close(figG);

        tripIdx = tripIdx + 1;
    end
end

%% 4) save ---------------------------------------------------------------
DRTresults = Results;                           % rename
save(fullfile(drtDir,'DRTresults.mat'), ...
     'DRTresults','gamma_est','RMSE_V','-v7.3');

fprintf('\n▶ 완료:  %s  에  DRTresults.mat  및 모든 그림 저장 완료\n',drtDir);
disp('Run_DRT_from_Results: complete.');

