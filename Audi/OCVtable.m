%% load_and_parse_RPT.m
%  64 Ah Pack RPT CSV  ➜  table(data) + segments{1…k} + 그래프
%  작성: 2025-05-19  (ChatGPT 예시)

clc; clear; close all;

%% 1) CSV 경로 -------------------------------------------------------------
csvFile = 'G:\공유 드라이브\BSL_Audi\OCV\ESS_ch1_RPT_Result.csv';  % 필요 시 수정

%% 2) CSV → table (헤더 그대로) --------------------------------------------
opts  = detectImportOptions(csvFile,'PreserveVariableNames',true);
Traw  = readtable(csvFile, opts);     % n×25 (원본)   ― 예) "Cycle Index", "Current(A)", …

%% 3) Total Time → Time_s (초) --------------------------------------------
tStr   = string(Traw.("Total Time"));             % "00:00:00.000" 등
sample = tStr(find(tStr ~= "",1));                % 첫 유효 샘플
fmt    = "mm:ss";                                 % 기본값
if count(sample,':') == 2, fmt = "hh:mm:ss"; end
if contains(sample,'.'),   fmt = fmt + ".SSS"; end
Traw.Time_s = seconds(duration(tStr,'InputFormat',fmt));   % 새 열 추가

%% 4) 변수 이름을 유효한 식별자로 통일 ------------------------------------
T = renamevars(Traw, Traw.Properties.VariableNames, ...
               matlab.lang.makeValidName(Traw.Properties.VariableNames));
           % 예) "Cycle Index"   → CycleIndex
           %     "Current(A)"    → Current_A_
           %     "Voltage(V)"    → Voltage_V_

data = T;      % === n×26 table : Workspace 에 ‘data’ 로 표시됩니다 ===

%% 5) 전류·전압 그래프 -----------------------------------------------------
I = data.Current_A_;
V = data.Voltage_V_;
t = data.Time_s;

figure('Name','64 Ah Pack – RPT','Color','w');
yyaxis left , plot(t,I,'LineWidth',1), ylabel('Current  I  [A]'), grid on
yyaxis right, plot(t,V,'LineWidth',1), ylabel('Voltage  V  [V]')
xlabel('Time  t  [s]'), title('ESS\_ch1  RPT  (64 Ah Pack)')
legend({'Current','Voltage'},'Location','best')

%% 6) CycleIndex 연속 구간으로 파싱 ---------------------------------------
cycleVar = 'CycleIndex';                    % renamevars 후 컬럼 이름
assert(ismember(cycleVar,data.Properties.VariableNames), ...
       'CycleIndex 열을 찾을 수 없습니다.');

cycle   = data.(cycleVar);                  % n×1
chgIdx  = find(diff(cycle) ~= 0);           % 값이 바뀌는 지점
bounds  = [1; chgIdx+1; height(data)+1];    % 구간 시작 인덱스
numSeg  = numel(bounds)-1;

segments = cell(numSeg,1);
for s = 1:numSeg
    segments{s} = data(bounds(s):bounds(s+1)-1 , :);   % table 슬라이스
end

fprintf('✔️  CycleIndex 기준으로 %d 개 구간(segments)을 생성했습니다.\n', numSeg);
disp('▶ 첫 구간 앞 3행 미리보기');  disp(head(segments{1},3));

% (선택) : Cycle1, Cycle2 … 변수로 워크스페이스에 풀어두고 싶다면 주석 해제
% for s = 1:numSeg
%     assignin('base', sprintf('Cycle%d', s), segments{s});
% end
%% load_and_parse_RPT.m
%  64 Ah Pack RPT CSV  ➜  table(data) + segments{1…k} + 그래프
%  작성: 2025-05-19  (ChatGPT 예시)

clc; clear; close all;

%% 1) CSV 경로 -------------------------------------------------------------
csvFile = 'G:\공유 드라이브\BSL_Audi\OCV\ESS_ch1_RPT_Result.csv';  % 필요 시 수정

%% 2) CSV → table (헤더 그대로) --------------------------------------------
opts  = detectImportOptions(csvFile,'PreserveVariableNames',true);
Traw  = readtable(csvFile, opts);     % n×25 (원본)   ― 예) "Cycle Index", "Current(A)", …

%% 3) Total Time → Time_s (초) --------------------------------------------
tStr   = string(Traw.("Total Time"));             % "00:00:00.000" 등
sample = tStr(find(tStr ~= "",1));                % 첫 유효 샘플
fmt    = "mm:ss";                                 % 기본값
if count(sample,':') == 2, fmt = "hh:mm:ss"; end
if contains(sample,'.'),   fmt = fmt + ".SSS"; end
Traw.Time_s = seconds(duration(tStr,'InputFormat',fmt));   % 새 열 추가

%% 4) 변수 이름을 유효한 식별자로 통일 ------------------------------------
T = renamevars(Traw, Traw.Properties.VariableNames, ...
               matlab.lang.makeValidName(Traw.Properties.VariableNames));
           % 예) "Cycle Index"   → CycleIndex
           %     "Current(A)"    → Current_A_
           %     "Voltage(V)"    → Voltage_V_

data = T;      % === n×26 table : Workspace 에 ‘data’ 로 표시됩니다 ===

%% 5) 전류·전압 그래프 -----------------------------------------------------
I = data.Current_A_;
V = data.Voltage_V_;
t = data.Time_s;

figure('Name','64 Ah Pack – RPT','Color','w');
yyaxis left , plot(t,I,'LineWidth',1), ylabel('Current  I  [A]'), grid on
yyaxis right, plot(t,V,'LineWidth',1), ylabel('Voltage  V  [V]')
xlabel('Time  t  [s]'), title('ESS\_ch1  RPT  (64 Ah Pack)')
legend({'Current','Voltage'},'Location','best')

%% 6) CycleIndex 연속 구간으로 파싱 ---------------------------------------
cycleVar = 'CycleIndex';                    % renamevars 후 컬럼 이름
assert(ismember(cycleVar,data.Properties.VariableNames), ...
       'CycleIndex 열을 찾을 수 없습니다.');

cycle   = data.(cycleVar);                  % n×1
chgIdx  = find(diff(cycle) ~= 0);           % 값이 바뀌는 지점
bounds  = [1; chgIdx+1; height(data)+1];    % 구간 시작 인덱스
numSeg  = numel(bounds)-1;

segments = cell(numSeg,1);
for s = 1:numSeg
    segments{s} = data(bounds(s):bounds(s+1)-1 , :);   % table 슬라이스
end

fprintf('✔️  CycleIndex 기준으로 %d 개 구간(segments)을 생성했습니다.\n', numSeg);
disp('▶ 첫 구간 앞 3행 미리보기');  disp(head(segments{1},3));

% (선택) : Cycle1, Cycle2 … 변수로 워크스페이스에 풀어두고 싶다면 주석 해제
% for s = 1:numSeg
%     assignin('base', sprintf('Cycle%d', s), segments{s});
% end
