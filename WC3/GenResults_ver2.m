%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Build_Results_allCells_mergeTrips_andPlot_savePNG.m   (2025-05-01 rev-f)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

%% (0) 사용자 설정 ---------------------------------------------------------
cellNums    = [57 58 59 60 61 62 63 64 71 72 79 80 89 91];
dataDir     = 'G:\공유 드라이브\BSL_WC';
outDirRoot  = 'Figures_PNG';
saveDir     = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\WC_DRT\PreResults';

Capacity_Ah = 5;
Q_batt_As   = Capacity_Ah*3600;

minZeroTail = 50;
plotTripsMax= 8;  plotsPerFig = 5;  subplotCols = 2;

%% (1) 폴더 준비 -----------------------------------------------------------
if ~exist(outDirRoot,'dir'), mkdir(outDirRoot); end
if ~exist(saveDir   ,'dir'), mkdir(saveDir);    end

%% (2) 결과 누적 구조체 ----------------------------------------------------
ResultsAll = struct([]);

%% ========================================================================
%                               셀 루프                                    %
%% ========================================================================
for ci = 1:numel(cellNums)
    cellID = cellNums(ci);
    fprintf('\n=== Processing cell %03d (%d/%d) ===\n',cellID,ci,numel(cellNums));

    %% 2-1) 데이터 로드 ----------------------------------------------------
    matFile = fullfile(dataDir,sprintf('cell_%03d_data.mat',cellID));
    if ~isfile(matFile)
        warning('   ▶ 파일 %s 없음 — 건너뜀',matFile);  continue; end
    load(matFile,'data');  nSteps = numel(data);

    %% 2-2) I 필드 보강 + avgI --------------------------------------------
    if ~isfield(data,'I')
        for i = 1:nSteps
            data(i).I = data(i).current * Capacity_Ah;
        end
    end
    for i = 1:nSteps, data(i).avgI = mean(data(i).I); end

    %% 2-3) 스텝 탐색 ------------------------------------------------------
    ocvIdx = find(abs([data.avgI] - (-0.025*Capacity_Ah)) < 1e-4);
    c2Idx  = find(abs([data.avgI] - (-0.5  *Capacity_Ah)) < 1e-4);
    c2Idx  = c2Idx(arrayfun(@(i) numel(data(i).time)>=50, c2Idx));

    drivingIdx = find(arrayfun(@(x) numel(x.state)>1 && ismember(x.step,[7 9]), data));
    drivingCyc = arrayfun(@(x) data(x).cyc, drivingIdx);
    uniqueCyc  = unique(drivingCyc);

    %% 2-4) Trip 병합 ------------------------------------------------------
    TripCell = cell(max(uniqueCyc),1);
    countTrailingZeros = @(v) find(v(end:-1:1)~=0,1,'first')-1;

    for cycVal = uniqueCyc.'
        idx = drivingIdx(drivingCyc==cycVal);
        raw = cell(numel(idx),1);
        for k = 1:numel(idx)
            sIdx = idx(k);
            if k==1 && sIdx>1 && data(sIdx-1).cyc==cycVal
                sIdx = sIdx-1;
            end
            if k < numel(idx)
                eIdx = idx(k+1) - 1;
            else
                eIdx = min(sIdx+1, nSteps);
            end
            seg = data(sIdx:eIdx);
            raw{k} = [vertcat(seg.voltage), vertcat(seg.I), vertcat(seg.time)];
        end
        merged={}; cur=raw{1}; k=1;
        while k<=numel(raw)
            if countTrailingZeros(cur(:,2)) >= minZeroTail || k==numel(raw)
                merged{end+1} = cur;  k = k+1;
                if k<=numel(raw), cur = raw{k}; end
            else
                k = k+1;  cur = [cur; raw{k}];
            end
        end
        TripCell{cycVal} = merged;
    end
    fprintf('   ▶ Trip 병합 완료 (minZeroTail=%d)\n',minZeroTail);

    %% 2-5) OCV–SOC 테이블 -------------------------------------------------
    soc_ocv = cell(numel(ocvIdx),1);
    for k = 1:numel(ocvIdx)
        s = ocvIdx(k);
        t = data(s).time;   I = data(s).I;   V = data(s).voltage;
        Q = cumtrapz(t,I);
        soc_ocv{k} = [1 - Q./Q(end), V(:)];
    end

    %% 2-6) Results(셀) ----------------------------------------------------
    nRes = numel(uniqueCyc);
    if numel(soc_ocv) < nRes
        warning('   ▶ OCV 스텝 부족 — 셀 %03d 건너뜀',cellID);  continue; end

    Results = repmat(struct(),1,nRes);
    for c = 1:nRes
        cyc = uniqueCyc(c);
        Results(c).cell_name = cellID;
        Results(c).cycle_num = cyc;
        for tIdx = 1:numel(TripCell{cyc})
            Results(c).(sprintf('Trips_%d',tIdx)) = TripCell{cyc}{tIdx};
        end
        Results(c).OCV = soc_ocv{c};
    end

    %% 2-7) C/2 용량·SOH ---------------------------------------------------
    if ~isempty(c2Idx)
        for k = 1:min(numel(c2Idx),numel(Results))
            s = c2Idx(k);
            Cap = -trapz(data(s).time, data(s).I)/3600;   % Ah
            Results(k).Cap_c2 = Cap;
        end
        refCap = Results(1).Cap_c2;
        for k = 1:numel(Results)
            if isfield(Results(k),'Cap_c2')
                Results(k).SOH = Results(k).Cap_c2 / refCap;
            else
                Results(k).Cap_c2 = [];  Results(k).SOH = [];
            end
        end
    else
        [Results.Cap_c2] = deal([]);  [Results.SOH] = deal([]);
    end

    %% 2-8) Trip-별 SoC ----------------------------------------------------
    for c = 1:numel(Results)
        ocvTbl = Results(c).OCV;
        if isempty(ocvTbl) || size(ocvTbl,2)<2
            warning('   ▶ cyc %d : OCV 없음 → SoC 스킵',Results(c).cycle_num);
            continue;
        end
        socFromV = @(v) interp1(ocvTbl(:,2), ocvTbl(:,1), v, 'linear','extrap');
        prevEndVolt = NaN;  tripIdx = 1;
        while true
            fld = sprintf('Trips_%d',tripIdx);
            if ~isfield(Results(c),fld), break; end
            T = Results(c).(fld);  if isempty(T), tripIdx=tripIdx+1; continue; end
            V = T(:,1);  I = T(:,2);  t = T(:,3);

            % 시작 전압 → SOC0
            if tripIdx == 1
                nz = find(I~=0,1,'first');
                if isempty(nz) || nz == 1
                    volt0 = V(1);
                else
                    volt0 = V(nz-1);
                end
            else
                volt0 = prevEndVolt;
            end
            soc0 = socFromV(volt0);

            % 적분 전하
            Idt = cumtrapz(t,I);  Qtrip = Idt(end);

            % 마지막 Trip 여부
            nextFld = sprintf('Trips_%d',tripIdx+1);
            isLast  = ~isfield(Results(c),nextFld) || isempty(Results(c).(nextFld));

            if isLast
                socVec = soc0 + Idt / Q_batt_As;
            else
                soc1 = socFromV(V(end));
                if Qtrip == 0
                    socVec = soc0 * ones(size(t));
                else
                    socVec = soc0 + (soc1 - soc0) .* (Idt / Qtrip);
                end
            end

            Results(c).(fld) = [V, I, t, t - t(1), socVec];
            prevEndVolt = V(end);  tripIdx = tripIdx + 1;
        end
    end

    %% 2-9) 그림(PNG) 저장 -------------------------------------------------
    outDir = fullfile(outDirRoot,sprintf('cell%03d',cellID));
    if ~exist(outDir,'dir'), mkdir(outDir); end

    % (a) Full Current + markers
    t_all = vertcat(data.time);  I_all = vertcat(data.I);
    figFC = figure('visible','off');
    plot(t_all,I_all,'b-'); grid on; hold on;
    plot(arrayfun(@(i)data(i).time(1),drivingIdx),...
         arrayfun(@(i)data(i).I(1),drivingIdx),'ro');
    if ~isempty(ocvIdx)
        plot(arrayfun(@(i)data(i).time(1),ocvIdx(1:numel(soc_ocv))),...
             arrayfun(@(i)data(i).I(1),ocvIdx(1:numel(soc_ocv))),'bo');
    end
    if ~isempty(c2Idx)
        plot(arrayfun(@(i)data(i).time(1),c2Idx),...
             arrayfun(@(i)data(i).I(1),c2Idx),'go');
    end
    xlabel('t [s]'); ylabel('I [A]');
    title(sprintf('cell %03d – Full Current',cellID));
    exportgraphics(figFC,fullfile(outDir,'FullCurrent_Markers.png'),'Resolution',300);
    close(figFC);

    % (b) Cycle-별 Voltage/Current 그림
    nCycles=numel(Results);  nFigs=ceil(nCycles/plotsPerFig);
    subplotRows=ceil(plotsPerFig/subplotCols);  cyclePtr=1;
    for fi = 1:nFigs
        figC = figure('visible','off');
        tiledlayout(subplotRows,subplotCols,'Padding','compact');
        for p = 1:plotsPerFig
            if cyclePtr > nCycles, break; end
            nexttile;

            big=[]; tB=[]; vB=[]; iB=[];
            for k = 1:plotTripsMax
                fld = sprintf('Trips_%d',k);
                if isfield(Results(cyclePtr),fld)&&~isempty(Results(cyclePtr).(fld))
                    T = Results(cyclePtr).(fld);
                    big=[big;T];
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
            ylabel('I [A]'); grid on;
            title(sprintf('cyc %d',Results(cyclePtr).cycle_num));
            xlabel('t [s]');
            cyclePtr=cyclePtr+1;
        end
        sgtitle(sprintf('cell %03d – Trip Parsing',cellID));
        exportgraphics(figC,fullfile(outDir,sprintf('TripsVoltage_cycSet_%02d.png',fi)),...
                       'Resolution',300);
        close(figC);
    end

    %% 2-10) ResultsAll 에 누적 (필드 동기화) ------------------------------
    if isempty(ResultsAll)
        ResultsAll = Results;
    else
        fnAll = fieldnames(ResultsAll);
        fnNew = fieldnames(Results);
        for f=setdiff(fnNew,fnAll)',  [ResultsAll.(f{1})] = deal([]);  end
        for f=setdiff(fnAll,fnNew)',  [Results.(f{1})]    = deal([]);  end
        ResultsAll = [ResultsAll ; Results];   %#ok<AGROW>
    end
    fprintf('   ▶ cell %03d 저장 (Cycles=%d)\n',cellID,numel(Results));
end

%% (3) 저장 ----------------------------------------------------------------
save(fullfile(saveDir,'Results.mat'),'ResultsAll');
fprintf('\n★★ 완료: Results.mat → "%s"\n',saveDir);

