%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run_DRT_from_Results.m   (rev-17, 2025-05-01)
% -------------------------------------------------------------------------
%  Input  : PreResults\Results.mat  (Trips_k: m×5 [V I t tRel SOC])
%  Output : DRTresults.mat
%           • Trips_k 그대로
%           • DRTk          : n×2  [θ  γ̂]
%           • PeakFeat_k    : p×3  [θ_pk  γ_pk  FWHM_pk]
%           • Trip별 전압-RMSE
%           + 그림(*.png)  ➔  VC_ALL / V_zoom / γ̂
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % θ-grid size
tau_max      = 2e4;        % τ_max [s]
lambda_hat   = 1.17 ; %1.17;       % ℓ₂-regularisation
Q_batt_Ah    = 5;          % capacity [Ah]
num_bs       = 100;        % bootstrap repeats (기본값)
pkPromMin    = 1e-3;       % MinPeakProminence [Ω]
edgeTol      = 0.1;        % 경계여유 [ln(s)]

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
if ~exist(drtDir,'dir'), mkdir(drtDir); end
if ~exist(figDir,'dir'), mkdir(figDir); end

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
for c = 4 %:nCycles
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d (index %d/%d) ===\n', cyc, c, nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d', tripIdx);
        if ~isfield(Results(c), fld) || isempty(Results(c).(fld)), break; end

        T  = Results(c).(fld);                   % [V I t tRel SOC]
        V  = T(:,1);  I = T(:,2);
        t  = T(:,3);  tRel = T(:,4);  SOC = T(:,5);

        fprintf('  > Trip %d  (N = %d)\n', tripIdx, numel(t));

        % -------- DRT estimation ----------------------------------------
        [g_hat,~,V_est] = DRT_estimation_aug( ...
            tRel, I, V, lambda_hat, n, tau_max, ...
            SOC, soc_values, ocv_values);

        % -------- RMSE ---------------------------------------------------
        rmse = sqrt(mean((V - V_est).^2));
        RMSE_V{c, tripIdx} = rmse;
        fprintf('      RMSE(V) = %.4f V\n', rmse);

        % -------- θ & γ̂ 저장 --------------------------------------------
        theta = linspace(log(0.1), log(tau_max), n).';
        Results(c).(sprintf('DRT%d', tripIdx))     = [theta, g_hat];
        gamma_est{c, tripIdx} = g_hat;

        % -------- bootstrap (그림용만, 저장 X) ---------------------------
        if num_bs_run > 0
            g_bs   = bootstrap_uncertainty_aug_FromResults( ...
                         tRel,I,V,lambda_hat,n,tau_max,num_bs_run, ...
                         SOC(1),Q_batt_Ah,soc_values,ocv_values);
            g_low  = prctile(g_bs,  5, 1).';
            g_high = prctile(g_bs, 95, 1).';
        else
            g_low = []; g_high = [];
        end

        % -------- 피크 & FWHM 추출 ---------------------------------------
        [pks, locs, widths] = findpeaks(g_hat, theta, ...
            'MinPeakProminence', pkPromMin, 'WidthReference', 'halfheight');
        keep = locs - widths/2 > min(theta) + edgeTol & ...
               locs + widths/2 < max(theta) - edgeTol;
        pks    = pks(keep);
        locs   = locs(keep);
        widths = widths(keep);
        Results(c).(sprintf('PeakFeat%d', tripIdx)) = [locs, pks, widths];

        %% ---------- 그림 1) 전압+전류 전체 --------------------------------
        figVC = figure('Visible','off');
        yyaxis left
        plot(t, V,       'k',  'LineWidth', 1.2); hold on
        plot(t, V_est,   '--', 'LineWidth', 1.2);
        ylabel('Voltage [V]');
        yyaxis right
        plot(t, I, 'b', 'LineWidth', 1);
        ylabel('Current [A]');
        xlabel('Absolute time [s]');
        title(sprintf('Cycle %d – Trip %d', cyc, tripIdx));
        legend({'V_{meas}','V_{est}','I'}, 'Location','best');
        grid on
        exportgraphics(figVC, fullfile(figDir, ...
            sprintf('VC_ALL_cyc%03d_trip%02d.png', cyc, tripIdx)), ...
            'Resolution', 300);
        close(figVC);

        %% ---------- 그림 2) 전압 비교 0–100 s -----------------------------
        figVZ = figure('Visible','on');
        plot(tRel, V,     'k',  'LineWidth', 1.2); hold on
        plot(tRel, V_est, '--', 'LineWidth', 1.2);
        xlabel('t_{rel} [s]');  ylabel('Voltage [V]');
        title(sprintf('Voltage (0–100 s) – C%d T%d', cyc, tripIdx));
        grid on;  xlim([0 100]);
        legend({'V_{meas}','V_{est}'}, 'Location','best');
        exportgraphics(figVZ, fullfile(figDir, ...
            sprintf('V_zoom_cyc%03d_trip%02d.png', cyc, tripIdx)), ...
            'Resolution', 300);
        %close(figVZ);

        %% ---------- 그림 3) γ̂, 피크, FWHM -------------------------------
        figG = figure('Visible','on');  hold on;  grid on

        % (a) bootstrap band (그림용만)
        if num_bs_run > 0
            fill([theta; flipud(theta)], ...
                 [g_low;  flipud(g_high)], ...
                 [0.8 0.8 0.8], ...
                 'EdgeColor','none', ...
                 'FaceAlpha',0.15, ...
                 'HandleVisibility','off');
        end

        % (b) γ̂ curve
        hGamma = plot(theta, g_hat, 'Color',[0.50 0.00 0.50], ...
                      'LineWidth',1.6);

        % (c) FWHM & Height
        hFWHM   = gobjects(numel(locs),1);
        hHeight = gobjects(numel(locs),1);
        for k = 1:numel(locs)
            xL = locs(k) - widths(k)/2;
            xR = locs(k) + widths(k)/2;
            hFWHM(k) = plot([xL xR], [pks(k)/2 pks(k)/2], ...
                            'r-', 'LineWidth', 1.3);
            hHeight(k) = plot([locs(k) locs(k)], [0 pks(k)], ...
                              'r--', 'LineWidth', 1.3);
        end

        % (d) Peaks
        hPeaks = plot(locs, pks, 'ro', ...
                      'MarkerFaceColor','r','MarkerSize',7);

        % labels
        xlabel('$\theta = \ln(\tau\,[\mathrm{s}])$', 'Interpreter','latex');
        ylabel('$\gamma\,[\Omega]$', 'Interpreter','latex');
        title(sprintf('\\gamma – Cycle %d, Trip %d', cyc, tripIdx), ...
              'Interpreter','tex');

        % legend
        legend([hGamma, hPeaks, hFWHM(1), hHeight(1)], ...
               {'$\gamma$', 'Peaks', 'FWHM', 'Height'}, ...
               'Location','northeast', 'Interpreter','latex');

        exportgraphics(figG, fullfile(figDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png', cyc, tripIdx)), ...
            'Resolution', 300); 
        close(figG);

        tripIdx = tripIdx + 1;
    end
end

% %% 4) save ---------------------------------------------------------------
% DRTresults = Results;  
% save(fullfile(drtDir,'DRTresults.mat'), ...
%      'DRTresults','gamma_est','RMSE_V','-v7.3');
% 
% fprintf('\n▶ 완료:  %s  에  DRTresults.mat 및 모든 그림 저장 완료\n', drtDir);
% disp('Run_DRT_from_Results: complete.');

