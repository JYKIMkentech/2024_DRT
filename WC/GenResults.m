%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Build_Results_cell59_mergeTrips_andPlot_savePNG.m  (2025‑04‑19, unclipped)
% -------------------------------------------------------------------------
%  2025‑04‑21 rev:   • 4th column = tRel (Trip‑relative time, t‑t(1))
%                   • 5th column = SOC
%                   • All plots/prints updated to use the new SOC column
%  2025‑04‑22 rev:   • Added C/2 step detection (like OCV step)
%                   • Marked C/2 steps with green ○ on full‐current plot
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

%% USER SETTINGS ----------------------------------------------------------
minZeroTail   = 50;      % I==0 tail samples ≥ minZeroTail → Trip boundary
plotTripsMax  = 8;       % Trip 1~8 concat 표시
plotsPerFig   = 5;       % Figure당 subplot 개수
subplotCols   = 2;       % subplot 열
outDir        = 'Figures_PNG';   % PNG 저장 폴더

Capacity_Ah   = 5;       % 5000 mAh
Q_batt_As     = Capacity_Ah * 3600;   % 18 000 A·s

%% 0) 저장 폴더 ------------------------------------------------------------
if ~exist(outDir,'dir'), mkdir(outDir); end

%% 1) 데이터 로드 ----------------------------------------------------------
load('G:\공유 드라이브\BSL_WC\cell_059_data.mat');   % 'data' 구조체
nSteps = numel(data);

%% 2) I 필드 보강 + avgI ---------------------------------------------------
if ~isfield(data,'I')
    for i = 1:nSteps
        data(i).I = data(i).current * Capacity_Ah;   % C‑rate → A
    end
end
for i = 1:nSteps
    data(i).avgI = mean(data(i).I);
end

%% 3) OCV 스텝 탐색 -------------------------------------------------------
target_C   = - 0.025;                 % ― 충전 0.025 C   (*기존 -0.025*)
tol_C      = 0.0001;                 % 허용 오차 (C‑rate 단위)
target_A   = target_C * Capacity_Ah; % 목표 전류 [A]

ocvIdx = find(abs([data.avgI] - target_A) < tol_C);

%% 3a) C/2 스텝 탐색 -------------------------------------------------------
target_C2   = 0.5;                   % C/2
tol_C2      = tol_C;                 % 같은 허용 오차 사용
target_A2   = target_C2 * Capacity_Ah;  % 목표 전류 [A]

% (1) C/2 스텝 인덱스 탐색
c2Idx = find(abs([data.avgI] - target_A2) < tol_C2);

% (2) 최소 데이터 포인트 개수(50개) 이상인 스텝만 남기기
minC2Points = 50;
c2Idx = c2Idx(arrayfun(@(i) numel(data(i).time) >= minC2Points, c2Idx));


%% 3b) OCV‑SOC 테이블 생성 ─ 충·방전 구분 ----------------------------------
soc_ocv_cell = cell(numel(ocvIdx),1);
isDischargeOCV = target_C < 0;       % 부호로 판단

for k = 1:numel(ocvIdx)
    s = ocvIdx(k);
    t = data(s).time;
    I = data(s).I;
    V = data(s).voltage;

    Q   = cumtrapz(t, I);            % 적분 전하 [A·s]

    if isDischargeOCV
        SoC = 1 - Q ./ Q(end);       % 방전 OCV (기존 방식)
    else
        SoC =      Q ./ Q(end);      % 충전 OCV 
    end

    soc_ocv_cell{k} = [SoC(:) , V(:)];
end

refOCV = soc_ocv_cell{1};            % [SoC  V]  (0→1 ↗︎)

%% 4) Driving 스텝 탐색 ----------------------------------------------------
drivingIdx     = find(arrayfun(@(x) ...
                    numel(x.state)>1 && ismember(x.step,[7 9]), data).').';
drivingCycles  = arrayfun(@(x) data(x).cyc, drivingIdx);
uniqueCycles   = unique(drivingCycles);

%% 5) TripCell (자동 병합) -------------------------------------------------
TripCell = cell(max(uniqueCycles),1);
countTrailingZeros = @(vec) find(vec(end:-1:1)~=0,1,'first')-1;

for cycVal = uniqueCycles.'
    idxList  = drivingIdx(drivingCycles==cycVal);               % 주행 스텝 인덱스
    rawTrips = cell(numel(idxList),1);

    % ---------- 수정된 블록 시작 ----------
    for k = 1:numel(idxList)
        % (1) Trip 의 시작 인덱스 ------------------------------------------------
        sIdx = idxList(k);

        % Trip1 에 한해서 바로 이전 스텝을 포함
        if k == 1
            prevIdx = sIdx - 1;
            if prevIdx >= 1 && data(prevIdx).cyc == cycVal        % 같은 사이클인지 확인
                sIdx = prevIdx;                                   % 하나 앞 스텝부터 시작
            end
        end

        % (2) Trip 의 끝 인덱스 --------------------------------------------------
        if k < numel(idxList)
            eIdx = idxList(k+1) - 1;      % 다음 주행 스텝 바로 전까지
        else
            eIdx = min(sIdx + 1, nSteps); % 마지막은 한 스텝만 더 (기존 로직 유지)
        end

        % (3) 데이터 슬라이스 ------------------------------------------------------
        seg         = data(sIdx:eIdx);
        rawTrips{k} = [vertcat(seg.voltage), ...
                       vertcat(seg.I),      ...
                       vertcat(seg.time)];
    end
    % ---------- 수정된 블록 끝 ----------

    % (b) tail‑zero 기준 병합 (그대로 둠)
    merged = {};
    cur    = rawTrips{1};  k = 1;
    while k <= numel(rawTrips)
        tailZeros = countTrailingZeros(cur(:,2));
        if (tailZeros >= minZeroTail) || (k==numel(rawTrips))
            merged{end+1} = cur;
            k = k + 1;
            if k <= numel(rawTrips), cur = rawTrips{k}; end
        else
            k   = k + 1;
            cur = [cur ; rawTrips{k}];
        end
    end
    TripCell{cycVal} = merged;
end
fprintf('▶ Trip 병합 완료 (minZeroTail = %d, Trip 1은 전‑스텝 포함)\n', ...
        minZeroTail);


%% 6) Results 구조체 -------------------------------------------------------
Results = struct([]);
for c = 1:numel(uniqueCycles)
    cycVal    = uniqueCycles(c);
    tripsHere = TripCell{cycVal};

    Results(c).cell_name = 59;
    Results(c).cycle_num = cycVal;
    for tIdx = 1:numel(tripsHere)
        Results(c).(sprintf('Trips_%d',tIdx)) = tripsHere{tIdx};  % [V I t]
    end
    Results(c).OCV   = refOCV;
end

%% 7) 전체 Current + 마커 -------------------------------------------------
t_all = vertcat(data.time);
I_all = vertcat(data.I);

fig1 = figure('Name','Full Current with Markers');
plot(t_all, I_all, 'b-'); hold on; grid on;
xlabel('Time [s]'); ylabel('Current [A]');
title('Full Current');

% Driving 마커
plot(arrayfun(@(i) data(i).time(1), drivingIdx), ...
     arrayfun(@(i) data(i).I(1),    drivingIdx), ...
     'ro', 'MarkerSize',6, 'LineWidth',1.2, 'DisplayName','Driving step');

% OCV 마커
plot(arrayfun(@(i) data(i).time(1), ocvIdx), ...
     arrayfun(@(i) data(i).I(1),    ocvIdx), ...
     'bo', 'MarkerSize',6, 'LineWidth',1.2, 'DisplayName','OCV step');

% C/2 마커
plot(arrayfun(@(i) data(i).time(1), c2Idx), ...
     arrayfun(@(i) data(i).I(1),    c2Idx), ...
     'go', 'MarkerSize',6, 'LineWidth',1.2, 'DisplayName','C/2 step');

legend('show','Location','best');
hold off;

exportgraphics(fig1, fullfile(outDir,'FullCurrent_Markers.png'), ...
               'Resolution',300);

%% 8) cycle별 Trips(Voltage) Figure ---------------------------------------
nCycles = numel(Results);
nFigs   = ceil(nCycles / plotsPerFig);
subplotRows = ceil(plotsPerFig / subplotCols);
cyclePtr = 1;

for figIdx = 1:nFigs
    figC = figure('Name',sprintf('TripsVoltage_fig%02d',figIdx));
    tiledlayout(subplotRows, subplotCols, 'Padding','compact');
    for p = 1:plotsPerFig
        if cyclePtr > nCycles, break; end
        nexttile;

        big = []; tB = []; vB = []; iB = [];
        for k = 1:plotTripsMax
            fld = sprintf('Trips_%d',k);
            if isfield(Results(cyclePtr),fld) && ~isempty(Results(cyclePtr).(fld))
                T   = Results(cyclePtr).(fld);        % [V I t]
                big = [big ; T];
                tB(end+1) = T(end,3);
                vB(end+1) = T(end,1);
                iB(end+1) = T(end,2);
            end
        end
        if isempty(big), cyclePtr = cyclePtr + 1; continue; end

        yyaxis left
        plot(big(:,3), big(:,1), 'b-'); hold on;
        plot(tB, vB, 'ko','MarkerFaceColor','w','MarkerSize',4);
        ylabel('V [V]');

        yyaxis right
        plot(big(:,3), big(:,2), 'r-');
        plot(tB, iB, 'ko','MarkerFaceColor','w','MarkerSize',4, ...
             'HandleVisibility','off');
        ylabel('I [A]'); grid on; hold off;

        title(sprintf('cyc %d', Results(cyclePtr).cycle_num));
        xlabel('t [s]');
        cyclePtr = cyclePtr + 1;
    end
    sgtitle('Trip Parsing with boundaries','FontWeight','bold');

    exportgraphics(figC, fullfile(outDir, ...
        sprintf('TripsVoltage_cycSet_%02d.png',figIdx)), 'Resolution',300);
end

%% 9) Trip별 SoC 계산 (前‑Trip 전압 사용, 마지막 Trip = 쿨롱카운팅) ---------
ocvV   = refOCV(:,2);
ocvSOC = refOCV(:,1);
[ocvVuniq, iu] = unique(ocvV,'stable');
socFromV = @(v) interp1(ocvVuniq, ocvSOC(iu), v, 'linear','extrap');

for c = 1:numel(Results)
    prevEndVolt = NaN;          % 직전 Trip 마지막 전압
    tripIdx     = 1;

    while true
        fld = sprintf('Trips_%d', tripIdx);
        if ~isfield(Results(c), fld), break; end
        T = Results(c).(fld);                    % [V I t …]
        if isempty(T), tripIdx = tripIdx + 1; continue; end

        V = T(:,1);  I = T(:,2);  t = T(:,3);

        % ---------- soc0 결정 --------------------------------------------
        if tripIdx == 1
            % Trip‑1 : I≠0 이 처음 나타나는 지점 직전 전압
            nzIdx = find(I ~= 0, 1, 'first');
            if isempty(nzIdx) || nzIdx == 1
                volt0 = V(1);                    % 전류가 끝까지 0 인 예외
            else
                volt0 = V(nzIdx-1);
            end
        else
            % Trip‑2 이후 : 직전 Trip 마지막 전압
            volt0 = prevEndVolt;
        end
        soc0 = socFromV(volt0);

        % ---------- 누적 전하 계산 ----------------------------------------
        Idt   = cumtrapz(t, I);                  % A·s
        Qtrip = Idt(end);

        % ---------- soc1 & SoC 벡터 ---------------------------------------
        nextFld    = sprintf('Trips_%d', tripIdx+1);
        isLastTrip = ~isfield(Results(c), nextFld) || isempty(Results(c).(nextFld));

        if isLastTrip
            % 마지막 Trip : 배터리 총용량 기준 쿨롱카운팅
            socVec = soc0 + Idt / Q_batt_As;
        else
            soc1   = socFromV(V(end));           % 자기 Trip 마지막 전압
            if Qtrip == 0
                socVec = soc0 * ones(size(t));
            else
                socVec = soc0 + (soc1 - soc0) .* (Idt / Qtrip);
            end
        end

        % ---------- 저장 ---------------------------------------------------
        tRel = t - t(1);
        Results(c).(fld) = [V, I, t, tRel, socVec];

        prevEndVolt = V(end);   % 다음 Trip 준비
        tripIdx     = tripIdx + 1;
    end
end
fprintf('▶ Trip‑wise SoC 계산 완료 (전‑Trip 전압 기반, 임계값 미사용)\n');


%% 10) cycle별 Voltage & SOC Figure ---------------------------------------
nFigs_SOC = ceil(nCycles / plotsPerFig);
cyclePtr  = 1;

for figIdx = 1:nFigs_SOC
    figS = figure('Name',sprintf('Volt_SOC_fig%02d',figIdx));
    tiledlayout(subplotRows, subplotCols, 'Padding','compact');
    for p = 1:plotsPerFig
        if cyclePtr > nCycles, break; end
        nexttile;

        big = []; tB = []; vB = []; socB = [];
        for k = 1:plotTripsMax
            fld = sprintf('Trips_%d',k);
            if isfield(Results(cyclePtr),fld) && ~isempty(Results(cyclePtr).(fld))
                T   = Results(cyclePtr).(fld);            % [V I t tRel SOC]
                big = [big ; T];
                tB(end+1)   = T(end,3);
                vB(end+1)   = T(end,1);
                socB(end+1) = T(end,5);
            end
        end
        if isempty(big), cyclePtr = cyclePtr + 1; continue; end

        yyaxis left
        plot(big(:,3), big(:,1), 'b-'); hold on;
        plot(tB, vB, 'ko','MarkerFaceColor','w','MarkerSize',4);
        ylabel('V [V]');

        yyaxis right
        plot(big(:,3), big(:,5)*100, 'g-');
        plot(tB, socB*100, 'ko','MarkerFaceColor','w','MarkerSize',4, ...
             'HandleVisibility','off');
        ylabel('SOC [%]'); grid on; hold off;

        title(sprintf('cyc %d', Results(cyclePtr).cycle_num));
        xlabel('t [s]');
        cyclePtr = cyclePtr + 1;
    end
    sgtitle('Trip Voltage & SOC','FontWeight','bold');

    exportgraphics(figS, fullfile(outDir, ...
        sprintf('Volt_SOC_cycSet_%02d.png',figIdx)), 'Resolution',300);
end

%% 11) Trip 1‑5 SOC 예시 출력 & 그래프 ------------------------------------
cycShow = 1;            % 확인할 cycle (Results 인덱스)
maxShow = 6;            % Trip 1~5
fprintf('\n▼ Example: cycle %d, Trip 1‑%d SOC summary\n', ...
        Results(cycShow).cycle_num, maxShow);
fprintf(' Trip  SOC0   SOC1   ΔSOC    Q_trip[A·s]\n');
fprintf('-------------------------------------------\n');

figE = figure('Name','Trip1‑5 SOC example'); hold on; grid on;
colors = lines(maxShow);

for tr = 1:maxShow
    fld = sprintf('Trips_%d', tr);
    if ~isfield(Results(cycShow), fld) || isempty(Results(cycShow).(fld)), break; end

    T       = Results(cycShow).(fld);
    t       = T(:,3);
    socVec  = T(:,5);
    I       = T(:,2);
    Idt     = cumtrapz(t - t(1), I);
    Qtrip   = Idt(end);

    soc0 = socVec(1);   soc1 = socVec(end);
    isLastFlag = tr==maxShow && ...
                 (~isfield(Results(cycShow), sprintf('Trips_%d',tr+1)) || ...
                  isempty(Results(cycShow).(sprintf('Trips_%d',tr+1))));
    if isLastFlag, soc1 = NaN; end

    fprintf(' %2d   %5.3f  %5.3f  %6.3f   %10.1f\n', ...
            tr, soc0, soc1, soc1-soc0, Qtrip);

    plot(t, socVec*100, '-', 'Color', colors(tr,:), ...
         'DisplayName', sprintf('Trip %d',tr));
end
xlabel('t  [s]'); ylabel('SOC  [%]');
title(sprintf('cycle %d  —  SOC profile of Trips 1‑%d', ...
      Results(cycShow).cycle_num, maxShow));
legend('Location','best'); hold off;

exportgraphics(figE, fullfile(outDir, ...
    sprintf('SOC_example_cycle%02d.png', Results(cycShow).cycle_num)), ...
    'Resolution',300);

%% 12) MAT 저장 ------------------------------------------------------------
save('Results.mat','Results');
fprintf('▶ 완료: Results.mat + PNG 파일들이 “%s” 폴더에 저장되었습니다.\n', ...
        outDir);



