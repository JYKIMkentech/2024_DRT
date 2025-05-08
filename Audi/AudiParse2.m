%% analyze_drive_all.m
% -------------------------------------------------------------------------
%  Audi Drive 데이터 일괄 처리 스크립트
%   • 대상 폴더: 2 4 6 8 10 12 14 16  (Raw.mat 포함)
%   • 출력 변수
%       ① Driving2, Driving4, ...        : 각 Trip_k = [V I t]  (nx3)
%       ② DrivingRefSOC2, DrivingRefSOC4 : 각 Trip_k = [soc t]  (nx2)
%   • 최종 저장: ParseResults_all.mat  (두 구조체를 한 번에 저장)
% -------------------------------------------------------------------------

clc; clear; close all;

%% 0) 사용자 설정 ----------------------------------------------------------
folderList = [2 4 6 8 10 12 14 16];   % 처리할 폴더 번호
gapThresh  = 500;                     % Δt jump 기준 [s]
basePath   = 'G:\공유 드라이브\BSL_Audi\Drive';

%% 1) 결과 저장용 구조체 초기화 -------------------------------------------
DrivingData     = struct();   % [V I t]  보관
DrivingRefSoC   = struct();   % [soc t]  보관

%% 2) 폴더 루프 -----------------------------------------------------------
for f = folderList
    fprintf('=== Folder %d 처리 중 ===\n', f);

    %% 2‑1) Raw.mat 로드 --------------------------------------------------
    matFile = fullfile(basePath, sprintf('Folder%d', f), 'Raw.mat');
    if ~exist(matFile, 'file')
        warning('⚠️  Raw.mat 누락 → Folder %d 스킵\n', f);
        continue;
    end
    load(matFile);                             % Raw.mat → struct 1개
    S = eval(whos('-file', matFile).name);     % 실제 struct 변수

    %% 2‑2) 필드 추출 -----------------------------------------------------
    tCurr = S.TimeCurr(:);   I   = S.Curr(:);
    tVolt = S.TimeVolt(:);   V   = S.Volt(:);
    tSoC  = S.TimeSoC(:);    soc = S.SoC(:);

    %% 2‑3) Trip 경계 계산 (Δt jump) --------------------------------------
    dt        = diff(tCurr);
    jumpAfter = find(dt > gapThresh) + 1;    % 점프 직후 인덱스
    jumpBefore= jumpAfter - 1;               % 점프 직전 인덱스

    startIdxs = [1 ; jumpAfter];             % Trip 시작
    endIdxs   = [jumpBefore ; numel(I)];     % Trip 끝
    numTrips  = numel(startIdxs);

    %% 2‑4) 구조체 이름 세팅 ---------------------------------------------
    drvFld  = sprintf('Driving%d', f);            % 예) Driving2
    socFld  = sprintf('DrivingRefSOC%d', f);      % 예) DrivingRefSOC2
    DrivingData.(drvFld)   = struct();            % 하위 필드 미리 생성
    DrivingRefSoC.(socFld) = struct();

    %% 2‑5) Trip별 데이터 저장 -------------------------------------------
    for k = 1:numTrips
        idxVIT = startIdxs(k):endIdxs(k);           % V, I, t 구간
        DrivingData.(drvFld).(sprintf('Trip%d',k)) = ...
            [ V(idxVIT) , I(idxVIT) , tCurr(idxVIT) ];

        % SoC 구간은 tSoC 범위로 필터링 (같은 시간창)
        tStart = tCurr(startIdxs(k));
        tEnd   = tCurr(endIdxs(k));
        idxSOC = find( (tSoC >= tStart) & (tSoC <= tEnd) );

        DrivingRefSoC.(socFld).(sprintf('Trip%d',k)) = ...
            [ soc(idxSOC) , tSoC(idxSOC) ];
    end

    fprintf('   → Trip %d개 완료\n', numTrips);
end

%% 3) 결과 저장 -----------------------------------------------------------
saveFile = fullfile(basePath, 'ParseResults_all.mat');
save(saveFile, 'DrivingData', 'DrivingRefSoC', '-v7');

fprintf('\n✅ 모든 작업 완료!  두 구조체를\n   %s\n   에 저장했습니다.\n', saveFile);
