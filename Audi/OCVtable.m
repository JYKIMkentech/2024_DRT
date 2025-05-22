%% genOCVtable.m
%  64 Ah Pack RPT CSV → table → struct array → OCV 스텝 검출 → SOC-OCV 테이블 생성
%  작성: 2025-05-22

clc; clear; close all;

%% 1) CSV 파일 경로 --------------------------------------------------------
csvFile = 'G:\공유 드라이브\BSL_Audi\OCV\ESS_ch1_RPT_Result.csv';  % 필요 시 수정

%% 2) CSV → table (헤더 그대로) --------------------------------------------
opts  = detectImportOptions(csvFile, 'PreserveVariableNames', true);
Traw  = readtable(csvFile, opts);   % 원본 테이블: n×25개 컬럼

%% 3) Total Time 문자열 → Time_s (duration 형) ---------------------------
tStr       = string(Traw.("Total Time"));  
firstValid = find(tStr ~= "", 1);
sample     = tStr(firstValid);
fmt        = "mm:ss"; 
if count(sample, ':') == 2,      fmt = "hh:mm:ss"; end
if contains(sample, '.'),        fmt = fmt + ".SSS"; end

Traw.Time_s = seconds(duration(tStr, 'InputFormat', fmt));

%% 4) 변수 이름을 MATLAB 식별자로 통일 ------------------------------------
T      = renamevars(Traw, Traw.Properties.VariableNames, ...
               matlab.lang.makeValidName(Traw.Properties.VariableNames));
data1  = T;   % n×26 table

%% 5) 전체 전류·전압 vs 시간 그래프 (data1 사용) ---------------------------
I_all = data1.Current_A_;
V_all = data1.Voltage_V_;
t_all = data1.Time_s;

figure('Name','64 Ah Pack – RPT','Color','w');
yyaxis left
  plot(t_all, I_all, 'LineWidth', 1);
  ylabel('Current I [A]');  grid on
yyaxis right
  plot(t_all, V_all, 'LineWidth', 1);
  ylabel('Voltage V [V]');
xlabel('Time t [s]');
title('ESS\_ch1 RPT (64 Ah Pack)');
legend({'Current','Voltage'}, 'Location','best');

%% 6) CycleIndex 연속 구간으로 파싱 → struct array (data) -----------------
cycleVar = 'CycleIndex';
assert( ismember(cycleVar, data1.Properties.VariableNames), ...
        'CycleIndex 열을 찾을 수 없습니다.' );

cycleVals = data1.(cycleVar);
chgIdx     = find(diff(cycleVals) ~= 0);
bounds     = [1; chgIdx + 1; height(data1) + 1];
numSeg     = numel(bounds) - 1;

template = struct( ...
    'voltage'    , [] , ...   % [V]
    'current'    , [] , ...   % [A]
    'time'       , [] , ...   % [s]
    'totalTime'  , [] , ...   % 원본 TotalTime 문자열
    'cycleIndex' , []         ...% scalar
);
data = repmat(template, numSeg, 1);

for s = 1:numSeg
    idx_seg = bounds(s):(bounds(s+1)-1);
    segT    = data1(idx_seg, :);
    
    data(s).voltage    = segT.Voltage_V_;
    data(s).current    = segT.Current_A_;
    data(s).time       = segT.Time_s;
    data(s).totalTime  = segT.TotalTime;
    data(s).cycleIndex = segT.CycleIndex(1);
end
fprintf('✔️  struct array(data)로 %d개 세그먼트 생성 완료\n', numSeg);

%% 7) data(2)에서 OCV 스텝 검출 (평균전류 ±3.2A, 최소 30포인트) ------------
seg       = data(2);
I         = seg.current;
V         = seg.voltage;
t         = seg.time;

% 7-1) 이동평균 노이즈 완화
win       = 5;
Iavg      = movmean(I, win, 'omitnan');

% 7-2) 기준 ±3.2 A ± 허용오차
targetCHG =  3.2;
targetDIS = -3.2;
tol       =  0.02;
maskCHG   = abs(Iavg - targetCHG) < tol;
maskDIS   = abs(Iavg - targetDIS) < tol;
mask      = maskCHG | maskDIS;

% 7-3) 연속된 true 구간 찾기
d      = diff([0; mask; 0]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;

% 7-3.5) 최소 포인트 필터링
minPts    = 30;
durations = ends - starts + 1;
valid     = durations >= minPts;
starts    = starts(valid);
ends      = ends(valid);

% 7-4) OCV 스텝 struct 생성
ocvSteps = struct('type',{}, 'time',{}, 'current',{}, 'voltage',{});
for k = 1:numel(starts)
    idx = starts(k):ends(k);
    if maskCHG(starts(k))
        thisType = 'OCVCHG';
    else
        thisType = 'OCVDIS';
    end
    ocvSteps(k).type    = thisType;
    ocvSteps(k).time    = t(idx);
    ocvSteps(k).current = I(idx);
    ocvSteps(k).voltage = V(idx);
end

% 7-5) 검출 결과 출력
fprintf('\n검출된 OCV 스텝 개수 (>= %d 포인트): %d\n', minPts, numel(ocvSteps));
for k = 1:numel(ocvSteps)
    fprintf('%s: 시작=%.1fs, 끝=%.1fs, 샘플=%d\n', ...
        ocvSteps(k).type, ...
        ocvSteps(k).time(1), ...
        ocvSteps(k).time(end), ...
        numel(ocvSteps(k).time));
end

% 7-6) 선택: 첫 번째 OCV 스텝 플롯 (Current 먼저, Voltage 우측)
figure('Name','OCV Step Sample','Color','w');
plot(ocvSteps(1).time, ocvSteps(1).current, 'LineWidth', 1);
ylim(prctile(ocvSteps(1).current,[1 99]));  % 스파이크 제거용
grid on
ylabel('Current [A]');

yyaxis right
plot(ocvSteps(1).time, ocvSteps(1).voltage, 'LineWidth', 1);
ylabel('Voltage [V]');

xlabel('Time [s]');
title(sprintf('Sample OCV Step: %s', ocvSteps(1).type));

%% 8) OCVCHG 스텝에서 SOC 계산 및 OCV-테이블 생성 -------------------------

% 8-1) OCVCHG 스텝 선택 (첫 번째)
chgIdx = strcmp({ocvSteps.type}, 'OCVCHG');
if ~any(chgIdx)
    error('OCVCHG 스텝을 찾을 수 없습니다.');
end
step   = ocvSteps(find(chgIdx,1));
t_chg  = step.time;
I_chg  = step.current;
V_chg  = step.voltage;

% 8-2) Coulomb-counting (cumtrapz)
Q      = cumtrapz(t_chg, I_chg);

% 8-3) SOC 정규화 (0 → 1)
soc    = Q / Q(end);

% 8-4) SOC-OCV 테이블 생성 (Nx2 double)
OCVtbl = [soc, V_chg];

% 8-5) .mat 파일로 저장 (공유 드라이브 OCV 폴더)
outDir = 'G:\공유 드라이브\BSL_Audi\OCV';
outFile = fullfile(outDir, 'OCVtable.mat');
save(outFile, 'OCVtbl');
fprintf('✔️ %s에 SOC-OCV 테이블 저장 완료 (크기: %dx2)\n', outFile, size(OCVtbl,1));


% 8-6) SOC-OCV 플롯
figure('Name','SOC vs OCV','Color','w');
plot(OCVtbl(:,1), OCVtbl(:,2), 'LineWidth', 1);
grid on
xlabel('State of Charge (SoC)');
ylabel('Open-Circuit Voltage (V)');
title('OCV vs SOC');


