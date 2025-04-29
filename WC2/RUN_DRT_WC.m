%%  Run_DRT_from_Results.m   (rev-9, 2025-04-23)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Input  : PreResults\Results.mat  (Trips_k: m×5 double [V I t tRel SOC])
%  Output : DRTresults.mat
%           • Trips_k 그대로
%           • DRTk      : n×2 [θ γ̂]
%           • PeakHWk   : p×2 [peakHeight  FWHM]
%           • Trip별 전압/전류, 전압확대,
%             γ̂(+피크·FWHM·높이 시각화) 그림
%           • Trip별 전압 RMSE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % theta grid size
tau_max      = 20000;      % τ_max [s]
lambda_hat   = 1.17;       % ℓ₂ regularisation
Q_batt_Ah    = 5;          % battery capacity [Ah]
num_bs       = 100;        % bootstrap repeats

%% PATHS ------------------------------------------------------------------
rootDir = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\WC_DRT';

preDir  = fullfile(rootDir,'PreResults');           % Results.mat  위치
drtDir  = fullfile(rootDir,'DRTResults');           % 결과 MAT
figDir  = fullfile(drtDir ,'DRT_Figures');          % 그림 디렉터리

if ~exist(drtDir,'dir'), mkdir(drtDir); end
if ~exist(figDir,'dir'), mkdir(figDir); end

%% 1) load data -----------------------------------------------------------
load(fullfile(preDir,'Results.mat'),'Results');      % 원본 구조체

soc_ocv    = Results(1).OCV;              % [SoC  V]
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);
nCycles    = numel(Results);

%% 2) containers ----------------------------------------------------------
gamma_est = {};        % γ̂ 단일 추정 (선택)
RMSE_V    = {};        % Trip별 전압 RMSE
peak_HW   = {};        % 피크 특징 [height  FWHM]

%% 3) main loop -----------------------------------------------------------
for c = 1 %:nCycles
    cyc = Results(c).cycle_num;
    fprintf('\n=== Cycle %d (index %d/%d) ===\n',cyc,c,nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld)), break; end

        Tmp  = Results(c).(fld);                % [V I t tRel SOC]
        V    = Tmp(:,1);  I   = Tmp(:,2);
        t    = Tmp(:,3);  tRel= Tmp(:,4);
        SOC  = Tmp(:,5);

        fprintf('  > Trip %d  (N = %d)\n',tripIdx,numel(t));

        % -------- (a) DRT estimation ------------------------------------
        [g_hat,R0_hat,V_est] = DRT_estimation_aug( ...
            tRel,I,V,lambda_hat,n,tau_max, ...
            SOC,soc_values,ocv_values);

        % -------- (b) RMSE ---------------------------------------------
        rmse = sqrt(mean((V-V_est).^2));
        RMSE_V{c,tripIdx} = rmse;
        fprintf('      RMSE(V) = %.4f V\n',rmse);

        % -------- (c) θ & γ̂ 저장 --------------------------------------
        theta = linspace(log(0.1),log(tau_max),n).';
        Results(c).(sprintf('DRT%d',tripIdx)) = [theta, g_hat];
        gamma_est{c,tripIdx} = g_hat;

        % -------- (d) 피크 특징 추출 -----------------------------------
        [pks,locs,widths] = findpeaks( ...
                g_hat, theta, ...
                'MinPeakProminence',0.01*max(g_hat), ...
                'WidthReference','halfheight');
        PeakHW = [pks(:), widths(:)];                 % p×2
        Results(c).(sprintf('PeakHW%d',tripIdx)) = PeakHW;
        peak_HW{c,tripIdx} = PeakHW;

        % -------- (e) bootstrap (선택) ---------------------------------
        g_bs = bootstrap_uncertainty_aug_FromResults( ...
            tRel,I,V,lambda_hat,n,tau_max,num_bs, ...
            SOC(1),Q_batt_Ah,soc_values,ocv_values);
        g_low  = prctile(g_bs,5 ,1).';
        g_high = prctile(g_bs,95,1).';

        % -------- (f) FIGURES ------------------------------------------
        % (f-1) 전압+전류 전체 (숨김)
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

        % (f-2) 전압 확대 0-100 s (숨김)
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

        % (f-3) γ̂(θ) + 피크 시각화 (화면 표시)
        figG = figure('Visible','on');                         % **on**
        plot(theta,g_hat,'Color',[0.5 0 0.5],'LineWidth',1.6); hold on

        % 빨간 ● 마커
        if ~isempty(pks)
            scatter(locs,pks,50,'r','filled');
        end

        % 각 피크: FWHM 가로선 & 높이 세로 점선
        for i = 1:numel(pks)
            xL = locs(i) - widths(i)/2;   % FWHM 왼쪽
            xR = locs(i) + widths(i)/2;   % FWHM 오른쪽
            yH = pks(i)/2;                % half-height

            % 가로선 (FWHM)
            plot([xL xR],[yH yH],'r-','LineWidth',1.2);
            % 세로 점선 (height)
            plot([locs(i) locs(i)],[0 pks(i)],'r--','LineWidth',0.9);
        end

        xlabel('\theta = ln(\tau [s])'); ylabel('\gamma [\Omega]');
        title(sprintf('\\gamma – Cycle %d, Trip %d',cyc,tripIdx));
        grid on
        legend({'\gamma','Peaks','FWHM','Height'},'Location','best');

        exportgraphics(figG,fullfile(figDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);

        tripIdx = tripIdx + 1;
    end
end

%% 4) save ---------------------------------------------------------------
DRTresults = Results;

save(fullfile(drtDir,'DRTresults.mat'), ...
     'DRTresults','gamma_est','RMSE_V','peak_HW','-v7.3');

fprintf('\n▶ 완료:  %s  에  DRTresults.mat  및 모든 그림 저장 완료\n',drtDir);
disp('Run_DRT_from_Results: complete.');


