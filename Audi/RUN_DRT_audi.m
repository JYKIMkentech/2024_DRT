%% RUN_DRT_audi.m
% -------------------------------------------------------------------------
% Folder별 Results(Driving SoC 포함)를 불러와서
% 각 Trip에 대해 cell 단위 DRT_estimation_aug를 실행하고,
% [theta, gamma] 행렬을 DRTresults.mat에 DRT# 필드로 저장하며,
% 세타·감마 분포와 전압 피팅 결과를 플롯
% -------------------------------------------------------------------------

clc; clear; close all;

%% 0) Folder 선택 ---------------------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
while true
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n\n', folderNum);
end

basePath   = 'G:\공유 드라이브\BSL_Audi\Drive';
folderPath = fullfile(basePath, sprintf('Folder%d', folderNum));

%% 1) Results 불러오기 ----------------------------------------------------
resFile = fullfile(folderPath, 'Results.mat');
if ~exist(resFile,'file')
    error('Results 파일이 없습니다:\n%s', resFile);
end
S         = load(resFile, 'Results');
ResultsIn = S.Results;
tripFields = fieldnames(ResultsIn);
tripFields(strcmp(tripFields,'Folder')) = [];    % 메타데이터 필드 제거

%% 2) OCV–SoC 테이블 로드 및 중복 전압 제거 -------------------------------
ocvDir  = 'G:\공유 드라이브\BSL_Audi\OCV';
ocvFile = fullfile(ocvDir, 'OCVtable.mat');
if ~exist(ocvFile,'file')
    error('OCVtable.mat 파일을 찾을 수 없습니다:\n%s', ocvFile);
end
T = load(ocvFile);
if isfield(T,'OCVtable')
    rawTbl = T.OCVtable;
elseif isfield(T,'OCVtbl')
    rawTbl = T.OCVtbl;
else
    error('OCVtable 또는 OCVtbl 변수가 MAT 파일에 없습니다.');
end
[Vuniq, ia] = unique(rawTbl(:,2), 'stable');
SoCuniq     = rawTbl(ia,1);

%% 3) 셀 및 pack 구성 정보 ------------------------------------------------
cellParallel    = 4;        % 병렬 셀 수
modulesInSeries = 36;       % 모듈 수
cellsPerModule  = 3;        % 모듈당 직렬 셀 수
cellSeries      = modulesInSeries * cellsPerModule;  % 직렬 셀 수
cellCapacityAh  = 64;       % pouch cell 용량 [Ah]
Q_cell_total    = cellCapacityAh * 3600;  % cell 총 전하량 [C]

%% 4) DRT 파라미터 설정 ---------------------------------------------------
lambda_hat = 13;    % 정규화 가중치
n          = 50;      % tau 그리드 포인트 수
dur        = 1e4;     % tau_max [s]

%% 5) Trip별 DRT 계산 및 플롯 ---------------------------------------------
DRTresults = struct('Folder', folderNum);

for i = 1:numel(tripFields)
    fld = tripFields{i};
    
    M     = ResultsIn.(fld);    % nx4 double: [V_pack, I_pack, t, soc]
    Vpack = M(:,1);
    Ipack = M(:,2);
    t     = M(:,3);
    SOC   = M(:,4);             % cell 기준 SoC
    
    % 5-1) pack → cell 변환
    Vcell = Vpack ./ cellSeries;
    Icell = Ipack ./ cellParallel;
    
    % 5-2) DRT 실행
    [gamma_est, R0_est, V_est, theta, tau, W_aug, y, OCV] = ...
        DRT_estimation_aug( ...
            t, Icell, Vcell, ...      % cell 단위 입력
            lambda_hat, n, dur, ...   
            SOC, ...                  % cell 기반 SOC
            SoCuniq, Vuniq ...        % OCV–SoC 테이블
        );
    
    % 5-3) 결과 저장
    idx = sscanf(fld,'Trip%d');
    DRTresults.(sprintf('DRT%d',idx)) = [theta, gamma_est];
    
    % 5-4) 플롯: Gamma 분포 vs tau
    figure('Name',sprintf('Folder %d – Trip %d: Gamma',folderNum,idx),'Color','w');
    semilogx(tau, gamma_est, '-', 'LineWidth',1.2);
    grid on;
    xlabel('Relaxation time \tau [s]');
    ylabel('\gamma(\tau)');
    title(sprintf('Trip %d – DRT Distribution \gamma vs \tau', idx));
    
    % 5-6) 플롯: 전압 피팅 비교 (측정 vs 모델)
    figure('Name',sprintf('Folder %d – Trip %d: Voltage Fit',folderNum,idx),'Color','w');
    plot(t, Vcell, 'b', t, V_est, 'r--', 'LineWidth',1.2);
    grid on;
    xlabel('Time [s]');
    ylabel('Cell Voltage [V]');
    legend('Measured V_{cell}', 'Fitted V_{est}', 'Location','best');
    title(sprintf('Trip %d – Voltage Fit', idx));
end

%% 6) 결과 저장 -----------------------------------------------------------
outFile = fullfile(folderPath, 'DRTresults.mat');
save(outFile, 'DRTresults');
fprintf('--- DRT 결과 및 플롯이 완료되었습니다. 저장 파일: %s ---\n', outFile);

