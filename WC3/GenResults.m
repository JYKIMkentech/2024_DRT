% Build_Results_cell59_mergeTrips_andPlot_savePNG.m  (2025-04-23, rev-c)
% -------------------------------------------------------------------------
%  2025-04-21 rev:   • 4th col = tRel, 5th col = SOC
%  2025-04-22 rev:   • Added C/2(+0.5C) step detection (green ○)
%  2025-04-23 rev-b: • C/2 탐색을 -0.5C(방전)로 변경
%  2025-04-24 rev-c: • refOCV 제거, ocvIdx별 soc–OCV 테이블을 Results(c).OCV에 개별 할당
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

%% USER SETTINGS ----------------------------------------------------------
minZeroTail   = 50;      % I==0 tail samples ≥ minZeroTail → Trip boundary
plotTripsMax  = 8;       % Trip 1~8 concat 표시
plotsPerFig   = 5;       % Figure당 subplot 개수
subplotCols   = 2;       % subplot 열수
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
        data(i).I = data(i).current * Capacity_Ah;   % C-rate → A
    end
end
for i = 1:nSteps
    data(i).avgI = mean(data(i).I);
end

%% 3) OCV 스텝 탐색 --------------------------------------------------------
target_C   = -0.025;                 % 충전 OCV: -0.025 C
tol_C      = 0.0001;                 % 허용 오차 (C-rate 단위)
target_A   = target_C * Capacity_Ah; % 목표 전류 [A]
ocvIdx     = find(abs([data.avgI] - target_A) < tol_C);

%% 3a) C/2(-0.5C) 스텝 탐색 ------------------------------------------------
target_C2   = -0.5;                  
tol_C2      = tol_C;                 
target_A2   = target_C2 * Capacity_Ah;
c2Idx       = find(abs([data.avgI] - target_A2) < tol_C2);
minC2Points = 50;
c2Idx = c2Idx(arrayfun(@(i) numel(data(i).time) >= minC2Points, c2Idx));

%% 3b) OCV–SOC 테이블 생성 (충·방전 구분) ----------------------------------
soc_ocv_cell   = cell(numel(ocvIdx),1);
isDischargeOCV = target_C < 0; 


for k = 1:numel(ocvIdx)
    s = ocvIdx(k);
    t = data(s).time;
    I = data(s).I;
    V = data(s).voltage;

    Q = cumtrapz(t, I);              
    if isDischargeOCV
        SoC = 1 - Q./Q(end);         
    else
        SoC =     Q./Q(end);         
    end
    soc_ocv_cell{k} = [SoC(:), V(:)];
end

%% 4) Driving 스텝 탐색 ----------------------------------------------------
drivingIdx    = find(arrayfun(@(x) ...
                   numel(x.state)>1 && ismember(x.step,[7 9]), data).').';
drivingCycles = arrayfun(@(x) data(x).cyc, drivingIdx);
uniqueCycles  = unique(drivingCycles);

%% 5) TripCell (자동 병합, Trip1 앞 스텝 포함) -----------------------------
TripCell = cell(max(uniqueCycles),1);
countTrailingZeros = @(vec) find(vec(end:-1:1)~=0,1,'first')-1;

for cycVal = uniqueCycles.'
    idxList  = drivingIdx(drivingCycles==cycVal);
    rawTrips = cell(numel(idxList),1);

    for k = 1:numel(idxList)
        sIdx = idxList(k);
        if k == 1
            prevIdx = sIdx - 1;
            if prevIdx >= 1 && data(prevIdx).cyc == cycVal
                sIdx = prevIdx;
            end
        end
        if k < numel(idxList)
            eIdx = idxList(k+1) - 1;
        else
            eIdx = min(sIdx + 1, nSteps);
        end
        seg         = data(sIdx:eIdx);
        rawTrips{k} = [vertcat(seg.voltage), ...
                       vertcat(seg.I),      ...
                       vertcat(seg.time)];
    end

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
fprintf('▶ Trip 병합 완료 (minZeroTail = %d, Trip 1은 전-스텝 포함)\n', minZeroTail);

%% 6) Results 구조체 생성 -------------------------------------------------
Results = struct([]);
nRes    = numel(uniqueCycles);
if numel(soc_ocv_cell) < nRes
    error('OCV 스텝 개수(%d)보다 사이클 수(%d)가 많습니다.', ...
          numel(soc_ocv_cell), nRes);
end

for c = 1:nRes
    cycVal    = uniqueCycles(c);
    tripsHere = TripCell{cycVal};

    Results(c).cell_name = 59;
    Results(c).cycle_num = cycVal;

    for tIdx = 1:numel(tripsHere)
        Results(c).(sprintf('Trips_%d',tIdx)) = tripsHere{tIdx};
    end
    
    Results(c).OCV = soc_ocv_cell{c};
    
end

%% 6a) C/2 스텝 용량(Ah) 계산 후 Results에 추가 -----------------------------
nCap = length(ocvIdx) - 1;  % 앞 20개만
if numel(c2Idx) < nCap, error('c2Idx가 %d개보다 적습니다.', nCap); end

for k = 1:nCap
    s = c2Idx(k);
    t = data(s).time;
    I = data(s).I;

    Q_As  = trapz(t, I);     
    CapAh = -Q_As / 3600;    

    Results(k).Cap_c2 = CapAh;
end
fprintf('▶ Cap_c2(-0.5C 방전) %.3f–%.3f Ah 계산 완료 및 Results에 저장.\n', ...
        min([Results(1:nCap).Cap_c2]), max([Results(1:nCap).Cap_c2]));

%% 7) 전체 Current + 마커 -------------------------------------------------
t_all = vertcat(data.time);
I_all = vertcat(data.I);

fig1 = figure('Name','Full Current with Markers');
plot(t_all, I_all, 'b-'); hold on; grid on;
xlabel('Time [s]'); ylabel('Current [A]');
title('Full Current');

plot(arrayfun(@(i) data(i).time(1), drivingIdx), ...
     arrayfun(@(i) data(i).I(1),    drivingIdx), ...
     'ro','MarkerSize',6,'LineWidth',1.2,'DisplayName','Driving');
plot(arrayfun(@(i) data(i).time(1), ocvIdx(1:nRes)), ...
     arrayfun(@(i) data(i).I(1),    ocvIdx(1:nRes)), ...
     'bo','MarkerSize',6,'LineWidth',1.2,'DisplayName','OCV');
plot(arrayfun(@(i) data(i).time(1), c2Idx(1:nCap)), ...
     arrayfun(@(i) data(i).I(1),    c2Idx(1:nCap)), ...
     'go','MarkerSize',6,'LineWidth',1.2,'DisplayName','-0.5C');
legend('show','Location','best');
exportgraphics(fig1, fullfile(outDir,'FullCurrent_Markers.png'),'Resolution',300);

%% 6b) SOH 계산 ------------------------------------------------------------
if isfield(Results,'c2_cap')
    Results = rmfield(Results,'c2_cap');
end
refCap = Results(1).Cap_c2;
for ii = 1:numel(Results)
    Results(ii).SOH = Results(ii).Cap_c2 / refCap;
end
fprintf('▶ SOH 계산 완료 (refCap = %.3f Ah, Results(:).SOH 추가)\n', refCap);

%% 8) cycle별 Trips(Voltage) Figure ---------------------------------------
nCycles     = numel(Results);
nFigs       = ceil(nCycles/plotsPerFig);
subplotRows = ceil(plotsPerFig/subplotCols);
cyclePtr    = 1;

for figIdx = 1:nFigs
    figC = figure('Name',sprintf('TripsVoltage_fig%02d',figIdx));
    tiledlayout(subplotRows,subplotCols,'Padding','compact');
    for p = 1:plotsPerFig
        if cyclePtr>nCycles, break; end
        nexttile;
        big=[]; tB=[]; vB=[]; iB=[];
        for k=1:plotTripsMax
            fld = sprintf('Trips_%d',k);
            if isfield(Results(cyclePtr),fld) && ~isempty(Results(cyclePtr).(fld))
                T = Results(cyclePtr).(fld);
                big = [big; T];
                tB(end+1)=T(end,3);
                vB(end+1)=T(end,1);
                iB(end+1)=T(end,2);
            end
        end
        if isempty(big), cyclePtr=cyclePtr+1; continue; end
        yyaxis left
        plot(big(:,3),big(:,1),'b-'); hold on;
        plot(tB,vB,'ko','MarkerFaceColor','w','MarkerSize',4);
        ylabel('V [V]');
        yyaxis right
        plot(big(:,3),big(:,2),'r-');
        plot(tB,iB,'ko','MarkerFaceColor','w','MarkerSize',4,'HandleVisibility','off');
        ylabel('I [A]'); grid on; hold off;
        title(sprintf('cyc %d',Results(cyclePtr).cycle_num));
        xlabel('t [s]');
        cyclePtr=cyclePtr+1;
    end
    sgtitle('Trip Parsing with boundaries','FontWeight','bold');
    exportgraphics(figC,fullfile(outDir, ...
        sprintf('TripsVoltage_cycSet_%02d.png',figIdx)),'Resolution',300);
end

%% 9) Trip별 SoC 계산 (前-Trip 전압, 마지막 Trip = 쿨롱카운팅) ----------------
for c = 1:numel(Results)
    ocvTbl = Results(c).OCV;           % [SoC V]
    ocvV   = ocvTbl(:,2);
    ocvSOC = ocvTbl(:,1);
    [ocvVuniq,iu] = unique(ocvV,'stable');
    socFromV = @(v) interp1(ocvVuniq,ocvSOC(iu),v,'linear','extrap');

    prevEndVolt = NaN;
    tripIdx     = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld), break; end
        T = Results(c).(fld);
        if isempty(T), tripIdx = tripIdx + 1; continue; end

        V = T(:,1); I = T(:,2); t = T(:,3);

        % (1) soc0 계산: 첫 점 전류가 0 이전 전압을 쓰거나 맨 첫 값
        if tripIdx == 1
            nzIdx = find(I~=0, 1, 'first');
            if isempty(nzIdx) || nzIdx == 1
                volt0 = V(1);
            else
                volt0 = V(nzIdx-1);
            end
        else
            volt0 = prevEndVolt;
        end
        soc0 = socFromV(volt0);

        % (2) 쿨롱카운팅으로 ΔQ
        Idt   = cumtrapz(t, I);
        Qtrip = Idt(end);

        % (3) socVec 생성
        nextFld = sprintf('Trips_%d',tripIdx+1);
        isLast  = ~isfield(Results(c), nextFld) || isempty(Results(c).(nextFld));
        if isLast
            % 마지막 Trip: 전체 용량 기준
            socVec = soc0 + Idt / Q_batt_As;
        else
            % 중간 Trip: 앞뒤 OCV 기준 보정
            soc1   = socFromV(V(end));
            if Qtrip == 0
                socVec = soc0 * ones(size(t));
            else
                socVec = soc0 + (soc1 - soc0) .* (Idt / Qtrip);
            end
        end

        % (4) 저장
        tRel = t - t(1);
        Results(c).(fld) = [V, I, t, tRel, socVec];

        prevEndVolt = V(end);
        tripIdx     = tripIdx + 1;
    end
end
fprintf('▶ Trip-wise SoC 계산 완료 (전-Trip 전압 기반, refOCV 없음)\n');


%% 10) cycle별 Voltage & SOC Figure ---------------------------------------
nFigs_SOC = ceil(nCycles/plotsPerFig);
cyclePtr  = 1;
for figIdx=1:nFigs_SOC
    figS = figure('Name',sprintf('Volt_SOC_fig%02d',figIdx));
    tiledlayout(subplotRows,subplotCols,'Padding','compact');
    for p=1:plotsPerFig
        if cyclePtr>nCycles, break; end
        nexttile;
        big=[]; tB=[]; vB=[]; socB=[];
        for k=1:plotTripsMax
            fld=sprintf('Trips_%d',k);
            if isfield(Results(cyclePtr),fld) && ~isempty(Results(cyclePtr).(fld))
                T=Results(cyclePtr).(fld);
                big=[big;T];
                tB(end+1)=T(end,3);
                vB(end+1)=T(end,1);
                socB(end+1)=T(end,5);
            end
        end
        if isempty(big), cyclePtr=cyclePtr+1; continue; end
        yyaxis left
        plot(big(:,3),big(:,1),'b-'); hold on;
        plot(tB,vB,'ko','MarkerFaceColor','w','MarkerSize',4);
        ylabel('V [V]');
        yyaxis right
        plot(big(:,3),big(:,5)*100,'g-');
        plot(tB,socB*100,'ko','MarkerFaceColor','w','MarkerSize',4,'HandleVisibility','off');
        ylabel('SOC [%]'); grid on; hold off;
        title(sprintf('cyc %d',Results(cyclePtr).cycle_num));
        xlabel('t [s]');
        cyclePtr=cyclePtr+1;
    end
    sgtitle('Trip Voltage & SOC','FontWeight','bold');
    exportgraphics(figS,fullfile(outDir, ...
        sprintf('Volt_SOC_cycSet_%02d.png',figIdx)),'Resolution',300);
end

%% 11) 모든 Trip → PreParseResults 구조체 배열 생성/저장 -------------------
saveDir = fullfile(basePath,'ParseResult');
if ~exist(saveDir,'dir'), mkdir(saveDir); end

nElem = numTrips + 1;                         % DrivingNum + Trip 개수
PreParseResults = repmat(struct( ...         % 모든 필드 미리 선언
    'DrivingNum', [], ...                    % 폴더 번호
    'TripName',   '', ...                    % 'Trip_#' 텍스트
    'Data',       []  ...                    % [V I t] 행렬
), 1, nElem);

% ── (a) element #1 : DrivingNum -----------------------------------------
PreParseResults(1).DrivingNum = folderNum;
PreParseResults(1).TripName   = 'DrivingNum';

% ── (b) element #2~N+1 : Trip 데이터 ------------------------------------
for kk = 1:numTrips
    idx = startIdxs(kk):endIdxs(kk);

    PreParseResults(kk+1).DrivingNum = [];   % 다른 요소와 field 맞춤
    PreParseResults(kk+1).TripName   = sprintf('Trip_%d',kk);
    PreParseResults(kk+1).Data       = [V(idx)  I(idx)  tCurr(idx)];
end

% ── (c) RefSOC 구조체 ----------------------------------------------------
RefSOC = struct('timeSOC', tSoC, 'soc', soc);

% ── (d) 저장 -------------------------------------------------------------
save(fullfile(saveDir,'PreParseResults.mat'),'PreParseResults');
save(fullfile(saveDir,'RefSOC.mat'),          'RefSOC');


%% 12) MAT 저장 ------------------------------------------------------------
saveDir = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\WC_DRT\PreResults';
if ~exist(saveDir,'dir'), mkdir(saveDir); end
save(fullfile(saveDir,'Results.mat'),'Results');
fprintf('▶ 완료: Results.mat 파일이 "%s" 폴더에 저장되었습니다.\n', saveDir);



