% Run_DRT_from_Results.m   (rev-19, 2025-05-25)
% -------------------------------------------------------------------------
% Input  : PreResults\Results.mat  (Trips_k: m×5 [V I t tRel SOC], OCV: [SoC V])
% Output : DRTresults.mat
%          • Trips_k 그대로
%          • DRTk           : n×2  [θ  γ̂]
%          • PeakFeat_k     : p×3  [θ_pk  γ_pk  FWHM_pk]
%          • Trip별 전압-RMSE (셀)
%          + 그림(*.png)  ➔  VC_ALL / V_zoom / γ̂
% 변경점 : (요청 2) 첫 샘플에서 V_meas와 V_est가 항상 일치하도록 OCV 앵커링
% -------------------------------------------------------------------------

clc; clear; close all;

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % θ-grid size
tau_max      = 2e4;        % τ_max [s]
lambda_hat   = 100;        % ℓ₂-regularisation
Q_batt_Ah    = 5;          % capacity [Ah] (부트스트랩 외에는 사용 안 함)
num_bs       = 100;        % bootstrap repeats (기본값)
pkPromMin    = 1e-3;       % MinPeakProminence [Ω]
edgeTol      = 0.1;        % 경계여유 [ln(s)]
anchorFirst  = true;       % 첫 샘플 전압 = OCV 앵커링

%% BOOTSTRAP TOGGLE -------------------------------------------------------
opt = input('Bootstrap 옵션 (1: 끔, 2: 켬) ▶ ');
switch opt
    case 1, num_bs_run = 0;
    case 2, num_bs_run = num_bs;
    otherwise, error('입력은 1 또는 2만 가능합니다.');
end
fprintf(' → 부트스트랩 반복 횟수: %d\n\n', num_bs_run);

%% PATHS ------------------------------------------------------------------
rootDir = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\WC_DRT';
preDir  = fullfile(rootDir,'PreResults');
drtDir  = fullfile(rootDir,'DRTResults');
figDir  = fullfile(drtDir ,'DRT_Figures');
if ~exist(drtDir,'dir'),  mkdir(drtDir); end
if ~exist(figDir,'dir'),  mkdir(figDir); end

%% 1) load data -----------------------------------------------------------
load(fullfile(preDir,'Results.mat'),'Results');
soc_ocv    = Results(1).OCV;           % [SoC  V]
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);
nCycles    = numel(Results);

%% 2) containers ----------------------------------------------------------
gamma_est  = {};   % γ̂
RMSE_V     = {};   % 전압-RMSE

%% 3) main loop -----------------------------------------------------------
for c = 2 %1:nCycles
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d (index %d/%d) ===\n', cyc, c, nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d', tripIdx);
        if ~isfield(Results(c), fld) || isempty(Results(c).(fld)), break; end

        T     = Results(c).(fld);        % [V I t tRel SOC]
        V     = T(:,1);
        I     = T(:,2);
        t     = T(:,3);
        tRel  = T(:,4);
        SOC   = T(:,5);

        fprintf('  > Trip %d  (N = %d)\n', tripIdx, numel(t));

        % ---- dt 벡터 및 dur 계산 --------------------------------------
        dt_rel = [tRel(1); diff(tRel)];     % 상대시간 간격 (dt(1)은 실제로 사용되지 않음)
        dur    = tau_max;                   % τ_max

        % ---- DRT estimation ------------------------------------------
        [g_hat, R0_hat, V_est, theta, W, y, OCV_vec] = DRT_estimation_aug( ...
            tRel, ...            % t
            I, ...               % ik
            V, ...               % V_sd
            lambda_hat, ...      % λ
            n, ...               % RC 격자
            dt_rel, ...          % dt
            dur, ...             % τ_max
            SOC, ...             % SOC (Trip의 5열)
            soc_values, ...      % SOC-OCV 데이터(SOC)
            ocv_values, ...      % SOC-OCV 데이터(OCV)
            anchorFirst);        % 첫 샘플 앵커 (요청 2)

        % ---- RMSE -----------------------------------------------------
        rmse = sqrt(mean((V - V_est).^2));
        RMSE_V{c, tripIdx} = rmse;
        fprintf('      RMSE(V) = %.4f V  |  R0̂ = %.4f Ω\n', rmse, R0_hat);

        % ---- θ & γ̂ 저장 ----------------------------------------------
        Results(c).(sprintf('DRT%d', tripIdx))  = [theta, g_hat];
        gamma_est{c, tripIdx}                  = g_hat;

        % ---- bootstrap (그림용만, 저장 X) -----------------------------
        g_low = []; g_high = [];
        if num_bs_run > 0
            if exist('bootstrap_uncertainty_aug_FromResults','file') == 2
                g_bs   = bootstrap_uncertainty_aug_FromResults( ...
                             tRel, I, V, lambda_hat, n, tau_max, num_bs_run, ...
                             SOC(1), Q_batt_Ah, soc_values, ocv_values);
                g_low  = prctile(g_bs,  5, 1).';
                g_high = prctile(g_bs, 95, 1).';
            else
                fprintf('      [경고] bootstrap 함수가 없어 부트스트랩을 건너뜁니다.\n');
            end
        end

        % ---- 피크 & FWHM 추출 ----------------------------------------
        [pks, locs, widths] = findpeaks(g_hat, theta, ...
            'MinPeakProminence', pkPromMin, 'WidthReference', 'halfheight');
        keep = locs - widths/2 > min(theta) + edgeTol & ...
               locs + widths/2 < max(theta) - edgeTol;
        pks    = pks(keep);
        locs   = locs(keep);
        widths = widths(keep);
        Results(c).(sprintf('PeakFeat%d', tripIdx)) = [locs, pks, widths];

        %% ------ 그림 1) 전압+전류 전체 --------------------------------
        figVC = figure('Visible','off');
        yyaxis left
        h1 = plot(t,     V,      'k',  'LineWidth',1.2); hold on;
        h2 = plot(t,     V_est, '--', 'LineWidth',1.2, 'Color',[0.8500 0.3250 0.0980]);  % orange
        ylabel('Voltage [V]');

        yyaxis right
        h3 = plot(t, I, 'b', 'LineWidth',1);
        ylabel('Current [A]');

        xlabel('Absolute time [s]');
        title(sprintf('Cycle %d – Trip %d', cyc, tripIdx));
        legend([h1 h2 h3], {'V_{meas}','V_{est}','I'}, 'Location','best');
        grid on
        exportgraphics(figVC, fullfile(figDir, ...
            sprintf('VC_ALL_cyc%03d_trip%02d.png', cyc, tripIdx)), ...
            'Resolution',300);

        %% ---- 그림 2) 전압＋전류 비교 0–100 s -------------------------
        figVZ = figure('Visible','on');
        yyaxis left
        h1z = plot(tRel,     V,      'k',  'LineWidth',1.2); hold on;
        h2z = plot(tRel,     V_est, '--', 'LineWidth',1.2, 'Color',[0.8500 0.3250 0.0980]);
        ylabel('Voltage [V]');

        yyaxis right
        h3z = plot(tRel, I, 'b', 'LineWidth',1);
        ylabel('Current [A]');

        xlabel('t_{rel} [s]');
        title(sprintf('Cycle %d – Trip %d: Voltage & Current (0–100 s)', cyc, tripIdx));
        grid on; xlim([0 100]);
        legend([h1z h2z h3z], {'V_{meas}','V_{est}','I'}, 'Location','best');
        exportgraphics(figVZ, fullfile(figDir, ...
            sprintf('VZoom_VC_cyc%03d_trip%02d.png', cyc, tripIdx)), ...
            'Resolution',300);

        %% ---- 그림 3) γ̂, 피크, FWHM ----------------------------------
        figG = figure('Visible','off'); hold on; grid on;
        if ~isempty(g_low)
            fill([theta; flipud(theta)], [g_low; flipud(g_high)], ...
                 [0.8 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.15, 'HandleVisibility','off');
        end
        hGamma = plot(theta, g_hat, 'Color',[0.50 0.00 0.50], 'LineWidth',1.6);
        hFWHM = gobjects(numel(locs),1); hHeight = gobjects(numel(locs),1);
        for k = 1:numel(locs)
            xL = locs(k) - widths(k)/2;
            xR = locs(k) + widths(k)/2;
            hFWHM(k)   = plot([xL xR], [pks(k)/2 pks(k)/2], 'r-', 'LineWidth',1.3);
            hHeight(k) = plot([locs(k) locs(k)], [0 pks(k)], 'r--','LineWidth',1.3);
        end
        plot(locs, pks, 'ro', 'MarkerFaceColor','r', 'MarkerSize',7);
        xlabel('\theta = ln(\tau [s])');
        ylabel('\gamma [\Omega]');
        title(sprintf('\\gamma – Cycle %d, Trip %d', cyc, tripIdx));
        exportgraphics(figG, fullfile(figDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png', cyc, tripIdx)), 'Resolution',300);
        close(figG);

        tripIdx = tripIdx + 1;
    end
end

%% 4) save ----------------------------------------------------------------
DRTresults = Results;
save(fullfile(drtDir,'DRTresults.mat'), 'DRTresults','gamma_est','RMSE_V','-v7.3');

fprintf('\n▶ 완료:  %s  에  DRTresults.mat 및 모든 그림 저장 완료\n', drtDir);
disp('Run_DRT_from_Results: complete.');

