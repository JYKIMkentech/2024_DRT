clc; clear; close all;

%% 0) 설정 -------------------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
basePath     = 'G:\공유 드라이브\BSL_Audi\Drive';
gapThresh    = 500;   % Δt > 500 s → Trip 경계
saveDir      = fullfile(basePath,'ParseResult');
if ~exist(saveDir,'dir'), mkdir(saveDir); end

%% 1) PreParseResultsALL / ParseResultsALL 프리할당 -------------------
maxTrips   = 116;   % 예약할 최대 Trip 개수
% 필드명 생성
tripFields = arrayfun(@(k) sprintf('Trip%d',k), 1:maxTrips, 'UniformOutput', false);
allFields  = ['DrivingNum', tripFields];
% 모두 빈 [] 로 채운 baseStruct
emptyVals  = repmat({[]}, 1, numel(allFields));
baseStruct = cell2struct(emptyVals, allFields, 2);
% struct 배열로 미리 할당
PreParseResultsALL = repmat(baseStruct, numel(validFolders), 1);
ParseResultsALL    = repmat(baseStruct, numel(validFolders), 1);

%% 2) 각 폴더별 처리 ------------------------------------------------
for i = 1:numel(validFolders)
    folderNum = validFolders(i);
    fprintf('--- Processing Folder %d ---\n', folderNum);
    rawFile = fullfile(basePath, sprintf('Folder%d',folderNum), 'Raw.mat');
    % 2.1) 데이터 로드
    S    = load(rawFile);
    fn   = fieldnames(S);
    data = S.(fn{1});
    tCurr = data.TimeCurr(:);
    I     = data.Curr(:);
    tVolt = data.TimeVolt(:);
    V     = data.Volt(:);
    tSoC  = data.TimeSoC(:);
    soc   = data.SoC(:);

    % 2.2) Δt-jump 경계 계산 → Trip 인덱스
    dt         = diff(tCurr);
    jumpAfter  = find(dt > gapThresh) + 1;
    jumpBefore = jumpAfter - 1;
    startIdxs  = [1; jumpAfter];
    endIdxs    = [jumpBefore; numel(I)];
    numTrips   = numel(startIdxs);

    %% 2.3) PreParseResultsALL 채우기 (모든 Trip)
    PR = baseStruct;
    PR.DrivingNum = folderNum;
    for k = 1:numTrips
        idx = startIdxs(k):endIdxs(k);
        PR.(sprintf('Trip%d',k)) = [ V(idx), I(idx), tCurr(idx) ];
    end
    PreParseResultsALL(i) = PR;

    %% 2.4) Trip별 메트릭 계산
    duration = zeros(numTrips,1);
    deltaSoc = zeros(numTrips,1);
    socStart = zeros(numTrips,1);
    socEnd   = zeros(numTrips,1);
    deltaI   = zeros(numTrips,1);
    for k = 1:numTrips
        % duration
        tS = tCurr(startIdxs(k));
        tE = tCurr(endIdxs(k));
        duration(k) = tE - tS;
        % SoC 변화
        [~, iS] = min(abs(tSoC - tS));
        [~, iE] = min(abs(tSoC - tE));
        socStart(k) = soc(iS);
        socEnd(k)   = soc(iE);
        deltaSoc(k) = abs(socEnd(k) - socStart(k));
        % Current 변화
        seg = I(startIdxs(k):endIdxs(k));
        deltaI(k) = max(seg) - min(seg);
    end

    %% 2.5) 조건 통과 Trip만 → ParseResultsALL 채우기
    isCand   = (duration >= 1000) & ...
               (deltaSoc  < 10)   & ...
               (min([socStart,socEnd],[],2) >= 20) & ...
               (deltaI    >= 100);
    candIdxs = find(isCand);

    PRc = baseStruct;
    PRc.DrivingNum = folderNum;
    for k = candIdxs(:).'
        PRc.(sprintf('Trip%d',k)) = PR.(sprintf('Trip%d',k));
    end
    ParseResultsALL(i) = PRc;

    %% 2.6) (선택) 폴더별 결과도 저장
    save(fullfile(saveDir, sprintf('PreParseResults_Folder%d.mat',folderNum)), 'PR');
    save(fullfile(saveDir, sprintf('ParseResults_Folder%d.mat',   folderNum)), 'PRc');
end

%% 3) 최종 저장 ------------------------------------------------------
save(fullfile(saveDir, 'PreParseResultsALL.mat'), 'PreParseResultsALL');
save(fullfile(saveDir, 'ParseResultsALL.mat'),    'ParseResultsALL');
fprintf('\n✅ 모든 작업 완료: PreParseResultsALL.mat 및 ParseResultsALL.mat 저장됨\n');
