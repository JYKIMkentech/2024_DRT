%% SIM-데이터 그래프 & PNG 저장
% ------------------------------------------------------------
%  • NE_Driving_fresh_4_1_SIM.mat → SIM_table (169×9)
%  • 선택 SIM 번호([1 80 120])에 대해
%      ① V,I-Time (2-축)   ② SOC-Time
%      → Figure 화면 + PNG(300 dpi) 저장
% ------------------------------------------------------------
clear; clc; close all;

%% 1) 데이터 로드 -----------------------------------------------------------
simMat = 'G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\SIM_parsed\NE_Driving_fresh_4_1_SIM.mat';
load(simMat,'SIM_table');

%% 2) 분석할 SIM 인덱스 -----------------------------------------------------
simIdx = [15 80 120];

%% 3) 출력 폴더 -------------------------------------------------------------
outDir = fullfile(pwd,'SIM_plots');  % 현재 폴더 밑에 SIM_plots/
if ~exist(outDir,'dir'), mkdir(outDir); end

%% 4) 스타일 ---------------------------------------------------------------
lw = 1.0;  colV = [0.00 0.45 0.74]; colI = [0.85 0.33 0.10]; colS = [0.00 0.60 0.25];

%% 5) 루프 -----------------------------------------------------------------
for idx = simIdx
    %--- 데이터 추출 -------------------------------------------------------
    t      = SIM_table.time{idx};
    V      = SIM_table.voltage{idx};
    I      = SIM_table.current{idx};
    socVec = SIM_table.SOC_vec{idx};

    %--- Figure -----------------------------------------------------------
    f = figure('Color','w','Name',sprintf('SIM %d',idx));
    tiledlayout(2,1,'TileSpacing','compact');

    % (1) V & I vs Time ---------------------------------------------------
    nexttile;
    yyaxis left
    plot(t,V,'-','Color',colV,'LineWidth',lw); ylabel('Voltage  [V]');
    yyaxis right
    plot(t,I,'-','Color',colI,'LineWidth',lw); ylabel('Current  [A]');
    xlabel('Time  [s]');
    title(sprintf('SIM %d  –  V & I vs Time',idx));
    grid on

    % (2) SOC vs Time -----------------------------------------------------
    nexttile;
    plot(t,socVec,'-','Color',colS,'LineWidth',lw);
    xlabel('Time  [s]'); ylabel('SOC  [%]');
    title('SOC vs Time'); grid on

    set(findall(f,'Type','axes'),'Box','on','LineWidth',0.8);

    %--- PNG 저장 ---------------------------------------------------------
    pngName = fullfile(outDir, sprintf('SIM_%03d.png',idx));
    exportgraphics(f, pngName, 'Resolution',300);   % R2020a+
    % saveas(f, pngName);  % 구버전 MATLAB이면 이 줄 활용
end

fprintf('✅ PNG 파일이 "%s" 폴더에 저장되었습니다.\n', outDir);


