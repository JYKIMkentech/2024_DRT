%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  RUN_LAB_DRT.m   (rev-04, 2025-07-14)
% -------------------------------------------------------------------------
%  ❯ 전압 피팅으로 DRT 추정 → Figure 3개(패널별) 생성
%  ❯ 색상 고정 : Voltage = 파랑, Current = 빨강
%  ❯ 창을 닫지 않으며, PNG 저장 옵션 유지
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;

%% 0) 사용자 설정 -----------------------------------------------------------
simMat  = ...
 'G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\SIM_parsed\NE_Driving_fresh_4_1_SIM.mat';
ocvMat  = ...
 'G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\OCV_0.05C.mat';

simIdx     = [15 80 120];        % 분석할 SIM 번호
n          = 201;                % θ-grid 개수
dur        = 2000;               % τ_max [s]
lambda_hat = 0.05;               % ℓ₂-정칙화
saveFig    = true;               % PNG 저장 여부

outDir = fullfile(pwd,'DRT_results');
if saveFig && ~exist(outDir,'dir'), mkdir(outDir); end

% --- 색상·굵기 ------------------------------------------------------------
colV = [0.00 0.45 0.74];   % Voltage 파랑
colI = [0.85 0.33 0.10];   % Current 빨강
lw   = 1.2;

%% 1) 데이터 로드 -----------------------------------------------------------
load(simMat,'SIM_table');    % 169×9 table
load(ocvMat,'NE_OCV');       % 37×2 table (SOC, V)
soc_values = NE_OCV.SOC;
ocv_values = NE_OCV.V;

%% 2) SIM 루프 --------------------------------------------------------------
for idx = simIdx
    % 2-1) 신호 추출 -------------------------------------------------------
    t   = SIM_table.time{idx}(:);
    V   = SIM_table.voltage{idx}(:);
    I   = SIM_table.current{idx}(:);
    SOC = SIM_table.SOC_vec{idx}(:);
    dt  = [t(1); diff(t)];
    
    % 2-2) DRT 추정 --------------------------------------------------------
    [gamma_est, R0_est, V_est, theta_discrete] = ...
        DRT_estimation_aug(t, I, V, lambda_hat, n, dt, dur, ...
                           SOC, soc_values, ocv_values);
    rmse = sqrt(mean((V - V_est).^2));
    
    %% === Figure 1 : 전체 V & I ==========================================
    f1 = figure('Color','w','Visible','on',...
                'Name',sprintf('SIM %d – 전체 V&I',idx),...
                'Units','pixels','Position',[50 50 800 350]);
    yyaxis left
    plot(t, V,'-','Color',colV,'LineWidth',lw,'DisplayName','V_{meas}'); hold on
    plot(t, V_est,'--','Color',colV,'LineWidth',lw,'DisplayName','V_{est}');
    ylabel('Voltage [V]');
    yyaxis right
    plot(t, I,'-','Color',colI,'LineWidth',lw,'DisplayName','I');
    ylabel('Current [A]');
    xlabel('Time [s]');
    title(sprintf('SIM %d – 전체 Voltage & Current',idx));
    legend('show','Location','best'); grid on
    
    if saveFig
        exportgraphics(f1, fullfile(outDir,sprintf('SIM_%03d_V_I.png',idx)), ...
                       'Resolution',300);
    end
    
    %% === Figure 2 : 0–100 s Voltage 확대 ================================
    f2 = figure('Color','w','Visible','on',...
                'Name',sprintf('SIM %d – 0–100 s',idx),...
                'Units','pixels','Position',[60 420 800 350]);
    t_rel = t - t(1);
    idx100 = t_rel <= 100;
    plot(t_rel(idx100), V(idx100),'-','Color',colV,'LineWidth',lw); hold on
    plot(t_rel(idx100), V_est(idx100),'--','Color',colV,'LineWidth',lw);
    xlabel('Time [s]'); ylabel('Voltage [V]');
    title(sprintf('Voltage Fit (0–100 s) – SIM %d',idx));
    legend({'V_{meas}','V_{est}'},'Location','best');  grid on
    
    if saveFig
        exportgraphics(f2, fullfile(outDir,sprintf('SIM_%03d_V100.png',idx)), ...
                       'Resolution',300);
    end
    
    %% === Figure 3 : γ(τ) 분포 ===========================================
    f3 = figure('Color','w','Visible','on',...
                'Name',sprintf('SIM %d – γ(τ)',idx),...
                'Units','pixels','Position',[70 790 800 350]);
    semilogx(exp(theta_discrete), gamma_est,'m-','LineWidth',1.2);
    xlabel('\tau  [s]'); ylabel('\gamma(\tau) [\Omega]');
    title(sprintf('\\gamma(\\tau) – SIM %d   (R_{0}=%.4f Ω,  RMSE=%.3f mV)', ...
                  idx, R0_est, rmse*1e3));
    grid on
    
    if saveFig
        exportgraphics(f3, fullfile(outDir,sprintf('SIM_%03d_gamma.png',idx)), ...
                       'Resolution',300);
    end
    
    %% --- 콘솔 출력 -------------------------------------------------------
    fprintf('[SIM %3d]  R0 = %.4f Ω   |   RMSE = %.3f mV\n', ...
             idx, R0_est, rmse*1e3);
end

fprintf('\n✅ 완료!   3개 Figure가 열렸고, PNG(옵션 선택)는 "%s"에 저장되었습니다.\n', outDir);

