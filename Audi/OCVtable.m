%% load_and_parse_RPT_struct_rename.m
%  64 Ah Pack RPT CSV  ➜  table(data1) + struct array(data) + 그래프
%  작성: 2025-05-19

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
if count(sample, ':') == 2, fmt = "hh:mm:ss"; end
if contains(sample, '.'), fmt = fmt + ".SSS"; end

Traw.Time_s = seconds(duration(tStr, 'InputFormat', fmt));

%% 4) 변수 이름을 MATLAB 식별자로 통일 ------------------------------------
T = renamevars(Traw, Traw.Properties.VariableNames, ...
               matlab.lang.makeValidName(Traw.Properties.VariableNames));

% ↓ 여기서 원본 테이블 이름을 data1 으로 변경
data1 = T;   % n×26 table

%% 5) 전류·전압 vs 시간 그래프 (data1 사용) -------------------------------
I = data1.Current_A_;
V = data1.Voltage_V_;
t = data1.Time_s;

figure('Name','64 Ah Pack – RPT','Color','w');
yyaxis left
  plot(t, I, 'LineWidth', 1);
  ylabel('Current I [A]');  grid on
yyaxis right
  plot(t, V, 'LineWidth', 1);
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

% 6-1) struct 템플릿 정의
template = struct( ...
    'voltage'    , [] , ...   % [V]
    'current'    , [] , ...   % [A]
    'time'       , [] , ...   % [s]
    'totalTime'  , [] , ...   % 원본 TotalTime 문자열
    'cycleIndex' , []       ...% scalar
);

% 6-2) struct array 초기화 (이제 변수 이름이 data)
data = repmat(template, numSeg, 1);

% 6-3) 각 구간별로 값 채우기
for s = 1:numSeg
    idx_seg = bounds(s):(bounds(s+1)-1);
    segT    = data1(idx_seg, :);  % table slice
    
    data(s).voltage    = segT.Voltage_V_;
    data(s).current    = segT.Current_A_;
    data(s).time       = segT.Time_s;
    data(s).totalTime  = segT.TotalTime;
    data(s).cycleIndex = segT.CycleIndex(1);
end

fprintf('✔️  struct array(data)로 %d개 세그먼트 생성 완료\n', numSeg);

% (테스트) 첫 구간 확인
disp('▶ data(1) 미리보기:');
disp(data(1));

