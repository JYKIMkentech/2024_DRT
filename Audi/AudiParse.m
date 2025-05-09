%% analyze_drive_folder.m
% -------------------------------------------------------------------------
%  Audi Drive 데이터 (Raw.mat)
%  • 전류 / 전압 / SoC 시각화
%  • Δt‑jump(>500 s) 기준 Trip 경계 표시
%  • PreParseResults.mat  : 모든 Trip(1–N) 저장
%    ParseResults.mat     : 조건 충족 Trip만 저장
%    RefSOC.mat           : SoC 레퍼런스
% -------------------------------------------------------------------------
%  조건 (ParseResults 선별용)
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
load(matFile);                       % Raw.mat 안에는 struct 하나
varsInMat = whos;
data      = eval(varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name);

%% 3) 필드 추출 ------------------------------------------------------------
tCurr = data.TimeCurr(:);   I   = data.Curr(:);
tVolt = data.TimeVolt(:);   V   = data.Volt(:);
tSoC  = data.TimeSoC(:);    soc = data.SoC(:);

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
gapThresh = 500;                      % Δt > 500 s → 경계
jumpAfter = find(dt > gapThresh) + 1; % 점프 직후 index
jumpBefore= jumpAfter - 1;            % 점프 직전 index
gapIdx    = unique([jumpBefore; jumpAfter]);
gapIdx(gapIdx < 1 | gapIdx > numel(I)) = [];
tBound    = tCurr(gapIdx);

%% 8) Trip 경계 시각화 (Current) ------------------------------------------
figure(figCurr); hold on;
ylC = ylim;
scatter(tCurr(gapIdx), I(gapIdx), 60, 'r', 'filled');
tBoundSort = sort(tBound);
for xb = tBoundSort.'
    plot([xb xb], ylC, 'k--', 'LineWidth', 0.8);
end
startIdxs = [1; jumpAfter];
endIdxs   = [jumpBefore; numel(I)];
numTrips  = numel(startIdxs);
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylC(1) + 0.05*(ylC(2)-ylC(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), ...
        'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
        'FontWeight','bold', 'Color','k');
end
legend({'Current','Boundaries'}, 'Location','best');

%% 9) Trip 경계 시각화 (Voltage) ------------------------------------------
figure(figVolt); hold on;
ylV = ylim;
scatter(tBoundSort, V(gapIdx), 60, 'r', 'filled');
for xb = tBoundSort.'
    plot([xb xb], ylV, 'k--', 'LineWidth', 0.8);
end
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylV(1) + 0.05*(ylV(2)-ylV(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), ...
        'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
        'FontWeight','bold', 'Color','k');
end
legend({'Voltage','Boundaries'}, 'Location','best');

%% 10) Trip 경계 시각화 (SoC) ---------------------------------------------
figure(figSoC); hold on;
ylS = ylim;
closestSoCIdx = arrayfun(@(tb) ...
    find(abs(tSoC - tb) == min(abs(tSoC - tb)), 1, 'first'), ...
    tBoundSort);
scatter(tSoC(closestSoCIdx), soc(closestSoCIdx), 60, 'r', 'filled');
for xb = tBoundSort.'
    plot([xb xb], ylS, 'k--', 'LineWidth', 0.8);
end
legend({'SoC','Boundaries'}, 'Location','best');

%% 11) 모든 Trip → PreParseResults 저장 -----------------------------------
savePath = fullfile(basePath, 'ParseResult');
if ~exist(savePath,'dir'), mkdir(savePath); end

PreParseResults = struct();
for k = 1:numTrips
    idxs = startIdxs(k):endIdxs(k);
    PreParseResults.(sprintf('Trip%d',k)) = [V(idxs) I(idxs) tCurr(idxs)];
end
save(fullfile(savePath,'PreParseResults.mat'), 'PreParseResults');
RefSOC = struct('timeSOC', tSoC, 'soc', soc);
save(fullfile(savePath,'RefSOC.mat'), 'RefSOC');

%% 12) Trip별 ΔSoC · Duration · Range · ΔI 계산/표시 -----------------------
fprintf('\n===== Trip별 ΔSoC & Duration & SOC Range & ΔI =====\n');
figure(figSoC); hold on;

deltaSoc  = NaN(numTrips,1);
duration  = NaN(numTrips,1);
socStart  = NaN(numTrips,1);
socEnd    = NaN(numTrips,1);
deltaI    = NaN(numTrips,1);

for k = 1:numTrips
    % (a) 시간 구간
    tStart      = tCurr(startIdxs(k));
    tEnd        = tCurr(endIdxs(k));
    duration(k) = tEnd - tStart;          % [s]

    % (b) 시작·종료 SoC
    [~,idxStart] = min(abs(tSoC - tStart));
    [~,idxEnd  ] = min(abs(tSoC - tEnd  ));
    socStart(k)  = soc(idxStart);
    socEnd(k)    = soc(idxEnd);
    deltaSoc(k)  = abs(socEnd(k) - socStart(k));    % ΔSoC [%]

    % (c) 전류 변동 크기
    idxs      = startIdxs(k):endIdxs(k);
    deltaI(k) = max(I(idxs)) - min(I(idxs));        % ΔI [A]

    % (d) 콘솔 출력
    fprintf('Trip %2d : ΔSoC = %6.2f %% , Dur = %6.0f s , Range = %6.2f–%6.2f %% , ΔI = %7.2f A\n', ...
            k, deltaSoc(k), duration(k), socEnd(k), socStart(k), deltaI(k));

    % (e) SoC 그래프 라벨
    mid_t = (tStart + tEnd)/2;
    y1 = ylS(1) + 0.05*(ylS(2)-ylS(1));  % Trip 번호
    y2 = ylS(1) + 0.12*(ylS(2)-ylS(1));  % ΔSoC
    y3 = ylS(1) + 0.19*(ylS(2)-ylS(1));  % Duration
    y4 = ylS(1) + 0.26*(ylS(2)-ylS(1));  % Range
    y5 = ylS(1) + 0.33*(ylS(2)-ylS(1));  % ΔI

    text(mid_t, y1, sprintf('Trip %d', k), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontWeight','bold','Color','k');
    text(mid_t, y2, sprintf('ΔSoC=%.2f%%', deltaSoc(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',8,'Color',[0.1 0.1 0.1]);
    text(mid_t, y3, sprintf('Dur=%.0f s', duration(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',8,'Color',[0.1 0.1 0.1]);
    text(mid_t, y4, sprintf('Range %.2f–%.2f%%', socEnd(k), socStart(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',8,'Color',[0.1 0.1 0.1]);
    text(mid_t, y5, sprintf('ΔI=%.2f A', deltaI(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize',8,'Color',[0.1 0.1 0.1]);
end

%% 13) 후보 Trip 선택 & ParseResults 저장 ---------------------------------
isCand = (duration >= 1000) & ...
         (deltaSoc  < 10)   & ...
         (min(socStart,socEnd) >= 20) & ...
         (deltaI    >= 100);

candTrips = find(isCand);
fprintf('\n=== 선택된 Trip (조건 충족) : %s ===\n', mat2str(candTrips));

ParseResults = struct();
for ii = 1:numel(candTrips)
    k   = candTrips(ii);
    idx = startIdxs(k):endIdxs(k);
    ParseResults.(sprintf('Trip%d',k)) = [V(idx) I(idx) tCurr(idx)];
end
save(fullfile(savePath,'ParseResults.mat'), 'ParseResults');

fprintf('\nPreParseResults.mat  (전체 %d개 Trip)\n', numTrips);
fprintf('ParseResults.mat     (조건 충족 %d개 Trip) 을 %s 에 저장했습니다.\n', ...
        numel(candTrips), savePath);



