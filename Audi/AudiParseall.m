% -------------------------------------------------------------------------
%  Audi Drive 데이터 (Raw.mat) 자동 처리 스크립트
%  • 모든 Folder(2,4,6,8,10,12,14,16)에 대해 Trip 분석 및 시각화
%  • Δt-jump(>500 s) 기준 Trip 경계 표시
%  • 개별 PreParseResults.mat 저장 및
%    모든 폴더 결과를 합친 PreParseResultsAll.mat 생성
% -------------------------------------------------------------------------
clc; clear; close all;

%% 설정 -------------------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
basePath     = 'G:\공유 드라이브\BSL_Audi\Drive';
gapThresh    = 500;   % Δt > 500 s → Trip 경계
saveDir      = fullfile(basePath,'ParseResult');
if ~exist(saveDir,'dir'), mkdir(saveDir); end

% 결과 저장용 임시 변수
allResults = cell(numel(validFolders),1);
numTripsArr = zeros(numel(validFolders),1);

%% 각 폴더별 처리 ------------------------------------------------
for i = 1:numel(validFolders)
    folderNum = validFolders(i);
    fprintf('--- Processing Folder %d ---\n', folderNum);
    matFile = fullfile(basePath, sprintf('Folder%d', folderNum), 'Raw.mat');
    if ~exist(matFile,'file')
        warning('Raw.mat 파일을 찾을 수 없습니다: %s', matFile);
        continue;
    end

    % 데이터 로드
    S = load(matFile);
    fn = fieldnames(S);
    data = S.(fn{1});

    % 시간·신호 벡터
    tCurr = data.TimeCurr(:); I = data.Curr(:);
    tVolt = data.TimeVolt(:); V = data.Volt(:);
    tSoC  = data.TimeSoC(:);    soc = data.SoC(:);

    % Δt jump 경계 계산
    dt        = diff(tCurr);
    jumpAfter = find(dt > gapThresh) + 1;
    jumpBefore= jumpAfter - 1;
    gapIdx    = unique([jumpBefore; jumpAfter]);
    gapIdx(gapIdx < 1 | gapIdx > numel(I)) = [];
    tBound    = sort(tCurr(gapIdx));

    % Trip 시작·끝 인덱스
    startIdxs = [1; jumpAfter];
    endIdxs   = [jumpBefore; numel(I)];
    numTrips  = numel(startIdxs);
    numTripsArr(i) = numTrips;

    % 시각화 (생략 가능)
    % --- 생략 코드 ---

    % PreParseResults 구조체 생성
    PR = struct();
    PR.DrivingNum = folderNum;
    for k = 1:numTrips
        idxs = startIdxs(k):endIdxs(k);
        PR.(sprintf('Trip%d',k)) = [V(idxs), I(idxs), tCurr(idxs)];
    end

    % 개별 파일 저장
    save(fullfile(saveDir,sprintf('PreParseResults_Folder%d.mat',folderNum)),'PR');
    allResults{i} = PR;
end

%% 모든 폴더 결과 합치기 ---------------------------------------------
maxTrips = max(numTripsArr);
% PreParseResultsAll 구조체 배열 초기화
for i = 1:numel(validFolders)
    PR_all(i).DrivingNum = validFolders(i); %#ok<SAGROW>
    for k = 1:maxTrips
        field = sprintf('Trip%d',k);
        if isfield(allResults{i},field)
            PR_all(i).(field) = allResults{i}.(field);
        else
            PR_all(i).(field) = [];
        end
    end
end

% 저장
save(fullfile(saveDir,'PreParseResultsAll.mat'),'PR_all');
fprintf('모든 폴더 결과 합쳐서 PreParseResultsAll.mat 저장 완료.\n');
