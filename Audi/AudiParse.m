%% analyze_drive_folder.m
% -------------------------------------------------------------------------
%  Audi Drive 데이터 (Raw.mat)
%  • 전류 / 전압 / SoC 시각화
%  • Δt‑jump(>500 s) 기준 Trip 경계 표시
%
%  • PreParseResults.mat : DrivingNum + Trip1~N (모든 Trip 저장)
%  • ParseResults.mat    : DrivingNum + Trip1~N (조건 충족 Trip만 저장)
%  • RefSOC.mat          : SoC 레퍼런스
%
%  • TempData.mat        : TimeTemp + Temp 저장
%
%  Trip 선별 조건
%    ① duration ≥ 1000 s
%    ② ΔSoC    < 10 %
%    ③ min(socStart,socEnd) ≥ 20 %
%    ④ ΔI      ≥ 100 A
% -------------------------------------------------------------------------
clc; clear; close all;

%% 0) 폴더 번호 입력 -------------------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
while true 
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n\n', folderNum);
end

%% 1) 파일 경로 설정 -------------------------------------------------------
basePath = 'G:\공유 드라이브\BSL_Audi\Drive';
matFile  = fullfile(basePath, sprintf('Folder%d', folderNum), 'Raw.mat');
if ~exist(matFile,'file')
    error('Raw.mat 파일을 찾을 수 없습니다:\n%s', matFile);
end

%% 2) 데이터 로드 ----------------------------------------------------------
load(matFile);  % Raw.mat 안에는 struct 하나
varsInMat = whos;
data      = eval(varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name);

%% 3) 필드 추출 ------------------------------------------------------------
% Current
tCurr = data.TimeCurr(:);
I     = data.Curr(:);
% Voltage
tVolt = data.TimeVolt(:);
V     = data.Volt(:);
% SoC
tSoC  = data.TimeSoC(:);
soc   = data.SoC(:);
% Temperature (추가)
if isfield(data,'TimeTemp') && isfield(data,'Temp')
    tTemp = data.TimeTemp(:);
    temp  = data.Temp(:);
else
    warning('온도 필드가 존재하지 않습니다.');
    tTemp = [];
    temp  = [];
end

%% 4) 전류 플롯 ------------------------------------------------------------
figCurr = figure('Name', sprintf('Current – Folder %d', folderNum));
plot(tCurr, I, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('Current [A]'); title('Pack Current');

%% 5) SoC 플롯 -------------------------------------------------------------
figSoC = figure('Name', sprintf('SoC – Folder %d', folderNum));
plot(tSoC, soc, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('SoC [%]'); title('State of Charge');

%% 6) 전압 플롯 ------------------------------------------------------------
figVolt = figure('Name', sprintf('Voltage – Folder %d', folderNum));
plot(tVolt, V, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('Voltage [V]'); title('Pack Voltage');

%% 7) Δt jump 경계 계산 ----------------------------------------------------
dt        = diff(tCurr);
gapThresh = 500;                       % Δt > 500 s → 경계
jumpAfter = find(dt > gapThresh) + 1;  % 점프 직후 index
jumpBefore= jumpAfter - 1;             % 점프 직전 index
gapIdx    = unique([jumpBefore; jumpAfter]);
gapIdx(gapIdx < 1 | gapIdx > numel(I)) = [];
tBound    = tCurr(gapIdx);

% Trip 경계 인덱스
startIdxs = [1; jumpAfter];
endIdxs   = [jumpBefore; numel(I)];
numTrips  = numel(startIdxs);

%% 8) Trip 경계 시각화 (Current) ------------------------------------------
figure(figCurr); hold on;
ylC = ylim;
scatter(tCurr(gapIdx), I(gapIdx), 60, 'r', 'filled');
for xb = sort(tBound).'
    plot([xb xb], ylC, 'k--', 'LineWidth', 0.8);
end
% Trip 라벨링
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylC(1) + 0.05*(ylC(2)-ylC(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), 'HorizontalAlignment','center', 'FontWeight','bold');
end
legend({'Current','Boundaries'}, 'Location','best');

%% 9) Trip 경계 시각화 (Voltage) ------------------------------------------
figure(figVolt); hold on;
ylV = ylim;
scatter(tCurr(gapIdx), V(gapIdx), 60, 'r', 'filled');
for xb = sort(tBound).'
    plot([xb xb], ylV, 'k--', 'LineWidth', 0.8);
end
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylV(1) + 0.05*(ylV(2)-ylV(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), 'HorizontalAlignment','center', 'FontWeight','bold');
end
legend({'Voltage','Boundaries'}, 'Location','best');

%% 10) Trip 경계 시각화 (SoC) ---------------------------------------------
figure(figSoC); hold on;
ylS = ylim;
closestSoCIdx = arrayfun(@(tb) find(abs(tSoC-tb)==min(abs(tSoC-tb)),1), sort(tBound));
scatter(tSoC(closestSoCIdx), soc(closestSoCIdx), 60, 'r', 'filled');
for xb = sort(tBound).'
    plot([xb xb], ylS, 'k--', 'LineWidth', 0.8);
end
legend({'SoC','Boundaries'}, 'Location','best');

%% 11) Trip별 ΔSoC · Duration · Range · ΔI 계산/표시 -----------------------

deltaSoc  = NaN(numTrips,1);
duration  = NaN(numTrips,1);
socStart  = NaN(numTrips,1);
socEnd    = NaN(numTrips,1);
deltaI    = NaN(numTrips,1);

for k = 1:numTrips
    % 시간 구간
    tStart = tCurr(startIdxs(k));
    tEnd   = tCurr(endIdxs(k));
    duration(k) = tEnd - tStart;

    % SoC 추출
    [~,i1] = min(abs(tSoC-tStart)); socStart(k) = soc(i1);
    [~,i2] = min(abs(tSoC-tEnd));   socEnd(k)   = soc(i2);
    deltaSoc(k)= abs(socEnd(k)-socStart(k));

    % ΔI 계산
    idx = startIdxs(k):endIdxs(k);
    deltaI(k) = max(I(idx)) - min(I(idx));

    % 콘솔 출력
    fprintf('Trip %2d : ΔSoC=%.2f%%, Dur=%.0f s, Range=%.2f–%.2f%%, ΔI=%.2f A\n', ...
        k, deltaSoc(k), duration(k), socStart(k), socEnd(k), deltaI(k));
end

%% 12) PreParseResults 및 온도 데이터 저장 -------------------------------
outputDir = fullfile(basePath, sprintf('Folder%d', folderNum));
if ~exist(outputDir,'dir'), mkdir(outputDir); end

% PreParseResults 생성·저장
PreParseResults = struct('DrivingNum',folderNum);
for k = 1:numTrips
    idx = startIdxs(k):endIdxs(k);
    PreParseResults.(sprintf('Trip%d',k)) = [V(idx), I(idx), tCurr(idx)];
end
save(fullfile(outputDir, sprintf('PreParseResults%d.mat', folderNum)), 'PreParseResults');

% 온도 데이터 저장
TempData = struct('timeTemp',tTemp,'temp',temp);
save(fullfile(outputDir, sprintf('TempData%d.mat', folderNum)), 'TempData');

%% 13) 조건 통과 Trip만 → ParseResults 구조체 생성/저장 --------------------

isCand = (duration>=1000) & (deltaSoc<10) & (min(cat(2,socStart,socEnd),[],2)>=20) & (deltaI>=100);
candTrips = find(isCand);

ParseResults = struct('DrivingNum',folderNum);
for k = candTrips'
    idx = startIdxs(k):endIdxs(k);
    ParseResults.(sprintf('Trip%d',k)) = [V(idx), I(idx), tCurr(idx)];
end
save(fullfile(outputDir, sprintf('ParseResults%d.mat', folderNum)), 'ParseResults');

%% 14) 조건 통과 Trip I&V plot (yyaxis 사용) -------------------------------
for k = candTrips'
    idx = startIdxs(k):endIdxs(k);
    t    = tCurr(idx);
    Iseg = I(idx);
    Vseg = V(idx);
    figure('Name', sprintf('Folder %d – Trip %d: I & V', folderNum, k));
    yyaxis left;  plot(t, Iseg,'LineWidth',1.2); ylabel('Current [A]');
    yyaxis right; plot(t, Vseg,'LineWidth',1.2); ylabel('Voltage [V]');
    xlabel('Time [s]'); title(sprintf('Folder %d – Trip %d: I & V', folderNum, k)); grid on;
end
