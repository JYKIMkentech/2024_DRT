%% analyze_drive_folder.m
% -------------------------------------------------------------------------
%  Audi Drive 데이터 (Raw.mat) • 전류/전압/SoC 시각화 + Trip 경계 표시
%  Trip 구간: Δt 점프(>500 s) 양쪽을 경계로 정의
%  + ParseResults.mat, RefSOC.mat 생성 및 저장
% -------------------------------------------------------------------------

clc; clear; close all;

%% 0) 폴더 번호 입력 --------------------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
while true
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n\n', folderNum);
end

%% 1) 파일 경로 설정 --------------------------------------------------------
basePath = 'G:\공유 드라이브\BSL_Audi\Drive';
matFile  = fullfile(basePath, sprintf('Folder%d', folderNum), 'Raw.mat');
if ~exist(matFile,'file')
    error('Raw.mat 파일을 찾을 수 없습니다:\n%s', matFile);
end

%% 2) 데이터 로드 ----------------------------------------------------------
load(matFile);  % Raw.mat 내 struct 하나
varsInMat = whos;
data      = eval( varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name );

%% 3) 필드 추출 ------------------------------------------------------------
tCurr = data.TimeCurr(:);
I     = data.Curr(:);

tVolt = data.TimeVolt(:);
V     = data.Volt(:);

tSoC  = data.TimeSoC(:);
soc   = data.SoC(:);

%% 4) 전류 플롯 ------------------------------------------------------------
figCurr = figure('Name', sprintf('Current – Folder %d', folderNum));
hCurr   = plot(tCurr, I, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('Current [A]');
title('Pack Current');

%% 5) SoC 플롯 -------------------------------------------------------------
figSoC = figure('Name', sprintf('SoC – Folder %d', folderNum));
hSoC   = plot(tSoC, soc, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('SoC [%]');
title('State of Charge');

%% 6) 전압 플롯 ------------------------------------------------------------
figVolt = figure('Name', sprintf('Voltage – Folder %d', folderNum));
hVolt   = plot(tVolt, V, 'b'); grid on; hold on;
xlabel('Time [s]'); ylabel('Voltage [V]');
title('Pack Voltage');

%% 7) Δt jump 경계 계산 --------------------------------------------------
dt        = diff(tCurr);
gapThresh = 500;                      % Δt > 500 s
jumpAfter = find(dt > gapThresh) + 1; % 점프 직후 index
jumpBefore= jumpAfter - 1;            % 점프 직전 index
gapIdx    = unique([jumpBefore; jumpAfter]);
gapIdx(gapIdx<1 | gapIdx>numel(I)) = [];
tBound    = tCurr(gapIdx);

%% 8) Trip 경계 시각화 (Current) -----------------------------------------
figure(figCurr); hold on;
ylC = ylim;

% ① 경계점(빨간 동그라미)
scatter(tCurr(gapIdx), I(gapIdx), 60, 'r', 'filled');

% ② 점선 그리기
tBoundSort = sort(tBound);
for xb = tBoundSort.'
    plot([xb xb], ylC, 'k--', 'LineWidth', 0.8);
end

% ③ 구역 시작·끝 인덱스
startIdxs = [1; jumpAfter];
endIdxs   = [jumpBefore; numel(I)];
numTrips  = numel(startIdxs);

% ④ Trip 번호 텍스트
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylC(1) + 0.05*(ylC(2)-ylC(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), ...
         'HorizontalAlignment','center', ...
         'VerticalAlignment','bottom', ...
         'FontWeight','bold', 'Color','k');
end

legend({'Current','Boundaries'}, 'Location','best');

%% 9) Trip 경계 시각화 (Voltage) -----------------------------------------
figure(figVolt); hold on;
ylV = ylim;

% ① 경계점(빨간 동그라미)
VBound = V(gapIdx);
scatter(tBoundSort, VBound, 60, 'r', 'filled');

% ② 점선 그리기
for xb = tBoundSort.'
    plot([xb xb], ylV, 'k--', 'LineWidth', 0.8);
end

% ③ Trip 번호 텍스트
for k = 1:numTrips
    mid_t = (tCurr(startIdxs(k)) + tCurr(endIdxs(k))) / 2;
    mid_y = ylV(1) + 0.05*(ylV(2)-ylV(1));
    text(mid_t, mid_y, sprintf('Trip %d', k), ...
         'HorizontalAlignment','center', ...
         'VerticalAlignment','bottom', ...
         'FontWeight','bold', 'Color','k');
end

legend({'Voltage','Boundaries'}, 'Location','best');

%% 10) ParseResults 및 RefSOC 저장 --------------------------------------
savePath = fullfile(basePath, 'ParseResult');
if ~exist(savePath,'dir')
    mkdir(savePath);
end

% ParseResults: Trip1, Trip2, … each Nx3 [V, I, t]
ParseResults = struct();
for k = 1:numTrips
    idxs   = startIdxs(k):endIdxs(k);
    V_seg  = V(idxs);
    I_seg  = I(idxs);
    t_seg  = tCurr(idxs);
    ParseResults.(['Trip' num2str(k)]) = [V_seg, I_seg, t_seg];
end
save(fullfile(savePath,'ParseResults.mat'), 'ParseResults');

% RefSOC: timeSOC, soc
RefSOC = struct('timeSOC', tSoC, 'soc', soc);
save(fullfile(savePath,'RefSOC.mat'), 'RefSOC');

fprintf('\nParseResults.mat 및 RefSOC.mat 을\n  %s 경로에 저장했습니다.\n', savePath);

