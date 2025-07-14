%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  SIM_an.m   (2025-07-14)
% -------------------------------------------------------------------------
%  ①  NE_Driving_fresh_4_1_SIM.mat   →  SIM_table (169×9)
%  ②  OCV_0.05C.mat                  →  NE_OCV    (37×2, 컬럼 = SOC·V)
%
%  • simIdx에 지정한 SIM 번호별로
%      ├─ Voltage & Current vs Time       (2-축)
%      └─ SOC vs Time
%    → PNG(300 dpi) 저장
%
%  • OCV 참조곡선(SOC–OCV)도 별도 PNG로 저장
%
%  저장 폴더 :  실행 폴더 하위  ./SIM_plots/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;

%% 0) 파일 경로 -------------------------------------------------------------
simMat = 'G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\SIM_parsed\NE_Driving_fresh_4_1_SIM.mat';
ocvMat = 'G:\공유 드라이브\BSL_Data4\HNE_agedcell_2025_processed\OCV_0.05C.mat';

%% 1) SIM 데이터 로드 -------------------------------------------------------
load(simMat,'SIM_table');        % -> 169×9 table

%% 2) OCV 데이터 로드 -------------------------------------------------------
%  파일 안에는 37×2 table 'NE_OCV'만 있다고 가정(SOC, V)
load(ocvMat,'NE_OCV');           % -> table 변수 하나만 불러옴
soc_OCV = NE_OCV.SOC;            % SOC   [%]  (0–100)
ocv_OCV = NE_OCV.V;              % OCV   [V]

%% 3) 분석할 SIM 번호 설정 --------------------------------------------------
simIdx = [1 80 120];             % 필요 시 수정

%% 4) 출력 폴더 준비 --------------------------------------------------------
outDir = fullfile(pwd,'SIM_plots');
if ~exist(outDir,'dir');  mkdir(outDir);  end

%% 5) 그래프 스타일 ---------------------------------------------------------
lw   = 1.0;
colV = [0.00 0.45 0.74];   % Voltage  파랑
colI = [0.85 0.33 0.10];   % Current  주황
colS = [0.00 0.60 0.25];   % SOC      초록

%% 6) SIM 루프 --------------------------------------------------------------
for idx = simIdx
    %--- 데이터 추출 --------------------------------------------------------
    t      = SIM_table.time{idx};       % 시간 [s]
    V      = SIM_table.voltage{idx};    % 전압 [V]
    I      = SIM_table.current{idx};    % 전류 [A]
    socVec = SIM_table.SOC_vec{idx};    % SOC  [%]
    
    %--- Figure 설정 --------------------------------------------------------
    f = figure('Color','w','Visible','off', ...
               'Name',sprintf('SIM %d',idx), ...
               'Units','pixels','Position',[100 100 800 600]);
    tiledlayout(2,1,'TileSpacing','compact');
    
    % (1) Voltage & Current vs Time ---------------------------------------
    nexttile;
    yyaxis left
    plot(t,V,'-','Color',colV,'LineWidth',lw);  ylabel('Voltage  [V]');
    yyaxis right
    plot(t,I,'-','Color',colI,'LineWidth',lw);  ylabel('Current  [A]');
    xlabel('Time  [s]');
    title(sprintf('SIM %d  –  V & I vs Time',idx));
    grid on
    
    % (2) SOC vs Time ------------------------------------------------------
    nexttile;
    plot(t,socVec,'-','Color',colS,'LineWidth',lw);
    xlabel('Time  [s]');  ylabel('SOC  [%]');
    title('SOC vs Time');  grid on
    
    set(findall(f,'Type','axes'),'Box','on','LineWidth',0.8);
    
    %--- PNG 저장 ----------------------------------------------------------
    pngName = fullfile(outDir, sprintf('SIM_%03d.png',idx));
    exportgraphics(f, pngName, 'Resolution',300);   % R2020a+
    % saveas(f, pngName);  % 구버전 MATLAB(2019b-)이면 이 줄 사용
    close(f);
end

%% 7) SOC-OCV 참조곡선 ------------------------------------------------------
f2 = figure('Color','w','Visible','off', ...
            'Name','SOC-OCV curve', ...
            'Units','pixels','Position',[100 100 600 450]);
plot(soc_OCV, ocv_OCV, 'k-', 'LineWidth',1.2);
xlabel('SOC  [%]');   ylabel('OCV  [V]');
title('SOC-OCV Curve (0.05C)');  grid on;  box on;

pngNameOCV = fullfile(outDir,'SOC_OCV_curve.png');
exportgraphics(f2, pngNameOCV, 'Resolution',300);
close(f2);

fprintf('✅ 그래프 PNG 파일들이 "%s" 폴더에 저장되었습니다.\n', outDir);


