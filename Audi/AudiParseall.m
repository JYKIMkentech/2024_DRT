%% AudiParseall.m  (2025-05-09 rev-b)
% -------------------------------------------------------------------------
%  Drive 폴더 8개(2·4·6·…·16) 일괄 파싱
%  • PreParseResults_All.mat : 모든 Trip
%  • ParseResults_All.mat    : 조건 충족 Trip
% -------------------------------------------------------------------------
clc; clear; close all;

%% 1) 사용자 설정 ----------------------------------------------------------
basePath     = 'G:\공유 드라이브\BSL_Audi\Drive';
validFolders = [2 4 6 8 10 12 14 16];

% Trip 선별 조건
minDur    = 1000;   % duration ≥ 1000 s
maxDSOC   = 10;     % ΔSoC    < 10 %
minSOC    = 20;     % SOC     ≥ 20 %
minDeltaI = 100;    % ΔI      ≥ 100 A
gapThresh = 500;    % Δt jump 판정 [s]

%% 2) 결과 구조체 초기화 ---------------------------------------------------
PreParseResults = struct();   % 모든 Trip
ParseResults    = struct();   % 조건 Trip만

%% 3) 폴더 순회 -----------------------------------------------------------
for folderNum = validFolders
    folderTag = sprintf('F%d',folderNum);           % 필드 이름 (F2, F4 …)
    matFile   = fullfile(basePath, sprintf('Folder%d',folderNum), 'Raw.mat');

    if ~exist(matFile,'file')
        warning('Raw.mat 누락 → Folder%d 건너뜀', folderNum);
        continue;
    end

    % ---------------------------------------------------------------------
    % 3‑1) Raw.mat 로드 & 올바른 struct 찾기
    % ---------------------------------------------------------------------
    S = load(matFile);             % 여러 변수가 들어 있을 수도 있음
    data = [];                     % 초기화
    fnTop = fieldnames(S);
    for ii = 1:numel(fnTop)
        cand = S.(fnTop{ii});
        if isstruct(cand) && all(isfield(cand, ...
              {'TimeCurr','Curr','TimeVolt','Volt','TimeSoC','SoC'}))
            data = cand;           % 원하는 struct 확보
            break;
        end
    end
    if isempty(data)
        warning('Folder%d : TimeCurr 등이 있는 struct 를 찾지 못했습니다.',folderNum);
        continue;
    end

    % ---------------------------------------------------------------------
    % 3‑2) 기본 신호 추출
    % ---------------------------------------------------------------------
    tCurr = data.TimeCurr(:);   I   = data.Curr(:);
    tVolt = data.TimeVolt(:);   V   = data.Volt(:);
    tSoC  = data.TimeSoC(:);    soc = data.SoC(:);

    % ---------------------------------------------------------------------
    % 3‑3) Trip 경계 계산 (Δt jump > gapThresh)
    % ---------------------------------------------------------------------
    dt        = diff(tCurr);
    jumpAfter = find(dt > gapThresh) + 1;    % 점프 직후 index
    jumpBefore= jumpAfter - 1;               % 점프 직전 index
    startIdxs = [1 ; jumpAfter];
    endIdxs   = [jumpBefore ; numel(I)];
    numTrips  = numel(startIdxs);

    % ---------------------------------------------------------------------
    % 3‑4) 모든 Trip → PreParseResults
    % ---------------------------------------------------------------------
    preSub = struct();
    for k = 1:numTrips
        idx = startIdxs(k):endIdxs(k);
        preSub.(sprintf('Trip%d',k)) = [V(idx) I(idx) tCurr(idx)]; % nx3
    end
    PreParseResults.(folderTag) = preSub;

    % ---------------------------------------------------------------------
    % 3‑5) Trip별 통계치 (ΔSoC·duration·ΔI)
    % ---------------------------------------------------------------------
    duration = nan(numTrips,1);
    deltaSoc = nan(numTrips,1);
    socStart = nan(numTrips,1);  socEnd = nan(numTrips,1);
    deltaI   = nan(numTrips,1);

    for k = 1:numTrips
        tStart      = tCurr(startIdxs(k));
        tEnd        = tCurr(endIdxs(k));
        duration(k) = tEnd - tStart;

        [~,iS] = min(abs(tSoC - tStart));
        [~,iE] = min(abs(tSoC - tEnd  ));
        socStart(k) = soc(iS);
        socEnd(k)   = soc(iE);
        deltaSoc(k) = abs(socEnd(k) - socStart(k));

        idx       = startIdxs(k):endIdxs(k);
        deltaI(k) = max(I(idx)) - min(I(idx));
    end

    % ---------------------------------------------------------------------
    % 3‑6) 조건 필터 & ParseResults
    % ---------------------------------------------------------------------
    isCand = (duration >= minDur) & ...
             (deltaSoc  <  maxDSOC) & ...
             (min(socStart,socEnd) >= minSOC) & ...
             (deltaI    >= minDeltaI);

    candTrips = find(isCand);
    fprintf('Folder %2d ▶ 후보 Trip = %s\n', folderNum, mat2str(candTrips));

    parseSub = struct();
    for jj = 1:numel(candTrips)
        k   = candTrips(jj);
        idx = startIdxs(k):endIdxs(k);
        parseSub.(sprintf('Trip%d',k)) = [V(idx) I(idx) tCurr(idx)];
    end
    ParseResults.(folderTag) = parseSub;   % (조건 통과 Trip 없으면 빈 struct)
end

%% 4) 저장 ----------------------------------------------------------------
save(fullfile(basePath,'PreParseResults_All.mat'), 'PreParseResults', '-v7');
save(fullfile(basePath,'ParseResults_All.mat')   , 'ParseResults'   , '-v7');

fprintf('\n=== 저장 완료 ===\n');
fprintf('  • PreParseResults_All.mat  (모든 Trip)\n');
fprintf('  • ParseResults_All.mat     (조건 충족 Trip)\n');
