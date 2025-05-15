% RUN_DRT_audi.m
% -------------------------------------------------------------------------
% Folder별 ParseResults와 RefSOC를 불러와서
% 각 Trip에 대해 DRT_estimation_aug를 실행하고,
% [theta, gamma] 행렬을 Results.mat에 DRT# 필드로 저장
% -------------------------------------------------------------------------

clc; clear; close all;

%% 0) Folder 선택
validFolders = [2 4 6 8 10 12 14 16];
while true
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n\n', folderNum);
end

basePath   = 'G:\공유 드라이브\BSL_Audi\Drive';
folderPath = fullfile(basePath, sprintf('Folder%d',folderNum));

%% 1) ParseResults, RefSOC 불러오기
prFile  = fullfile(folderPath, sprintf('ParseResults%d.mat', folderNum));
socFile = fullfile(folderPath, sprintf('RefSOC%d.mat',      folderNum));
if ~exist(prFile,'file'),  error('ParseResults 파일이 없습니다:\n%s', prFile);  end
if ~exist(socFile,'file'), error('RefSOC 파일이 없습니다:\n%s',    socFile); end

S1 = load(prFile);    ParseResults = S1.ParseResults;
S2 = load(socFile);   % contains RefSOC.timeSOC, RefSOC.soc
timeSOC = S2.RefSOC.timeSOC;
socRaw  = S2.RefSOC.soc;

%% 2) OCV_table.mat 검색: 먼저 Folder 아래, 없으면 basePath 아래
ocvInFolder = fullfile(folderPath,  'OCV_table.mat');
ocvInRoot   = fullfile(basePath,     'OCV_table.mat');
if     exist(ocvInFolder,'file')
    ocvTbl = ocvInFolder;
elseif exist(ocvInRoot,  'file')
    ocvTbl = ocvInRoot;
else
    error('OCV_table.mat 파일을 찾을 수 없습니다.\n경로하위: %s\n또는 기본경로: %s', ...
          ocvInFolder, ocvInRoot);
end

S3 = load(ocvTbl);    % contains soc_values, ocv_values
soc_values = S3.soc_values;
ocv_values = S3.ocv_values;

%% 3) DRT 파라미터 설정
lambda_hat = 1e-3;    % 정규화 가중치
n          = 50;      % tau 그리드 포인트 수
dur        = 1e4;     % tau_max [s]

%% 4) 각 Trip에 대해 DRT 계산
tripFields = fieldnames(ParseResults);
Results    = struct();
Results.DrivingNum = folderNum;

for i = 1:numel(tripFields)
    fld = tripFields{i};
    if strcmp(fld,'DrivingNum'), continue; end
    
    dat = ParseResults.(fld);   % [V, I, t]
    V   = dat(:,1);
    I   = dat(:,2);
    t   = dat(:,3);
    
    % RefSOC 시간→SOC 보간
    SOC_trip = interp1(timeSOC, socRaw, t, 'linear', 'extrap');
    
    % DRT 수행
    [gamma_est, R0_est, V_est, theta, tau, W_aug, y, OCV] = ...
        DRT_estimation_aug( ...
            t, I, V, ...              
            lambda_hat, n, dur, ...   
            SOC_trip, ...             
            soc_values, ocv_values ... 
        );
    
    idx = sscanf(fld,'Trip%d');
    Results.(sprintf('DRT%d',idx)) = [theta, gamma_est];
end

%% 5) 결과 저장
outFile = fullfile(folderPath,'Results.mat');
save(outFile,'Results');
fprintf('--- DRT 결과가 성공적으로 저장되었습니다: %s ---\n', outFile);
