%% load_RPT_table_plot.m  ─ 64 Ah Pack RPT CSV ➜ n×26 table(data) + 그래프
clc; clear; close all;

csvFile = 'G:\공유 드라이브\BSL_Audi\OCV\ESS_ch1_RPT_Result.csv';   % 경로 확인

% ── 1) CSV → table (헤더 보존) ────────────────────────────────────────────
opts = detectImportOptions(csvFile,'PreserveVariableNames',true);
T    = readtable(csvFile, opts);         % n × 25 (예)  ← CSV 그대로

% ── 2) Total Time → Time_s (초) 열 추가 ─────────────────────────────────
tStr   = string(T.("Total Time"));
sample = tStr(find(tStr ~= "",1));       % 첫 유효 샘플
fmt    = "mm:ss";
if count(sample,':') == 2, fmt = "hh:mm:ss"; end
if contains(sample,'.'),   fmt = fmt + ".SSS"; end
T.Time_s = seconds(duration(tStr,'InputFormat',fmt));

% ── 3) 변수 이름을 유효한 식별자로 정리 (공백/괄호 → 밑줄 등) ────────────
T = renamevars(T, T.Properties.VariableNames, ...
               matlab.lang.makeValidName(T.Properties.VariableNames));

% ── 4) table → data (그냥 별칭) ─────────────────────────────────────────
data = T;    % 이제 data 는 n×26 table, Workspace 에 n×26 로 표시됨

% ── 5) 그래프용 단축 변수 ──────────────────────────────────────────────
I = data.Current_A_;     % 전류 [A]    (Current(A) → Current_A_)
V = data.Voltage_V_;     % 전압 [V]    (Voltage(V) → Voltage_V_)
t = data.Time_s;         % 시간 [s]

% ── 6) 전류·전압 그래프 ────────────────────────────────────────────────
figure('Name','64 Ah Pack – RPT','Color','w');
yyaxis left , plot(t,I,'LineWidth',1), ylabel('Current  I  [A]'), grid on
yyaxis right, plot(t,V,'LineWidth',1), ylabel('Voltage  V  [V]')
xlabel('Time  t  [s]'), title('ESS\_ch1  RPT  (64 Ah Pack)')
legend({'Current','Voltage'},'Location','best')

% ── 7) 확인 예시 ───────────────────────────────────────────────────────
disp(data(1:3,1:6))       % 앞 3행, 6개 변수만 맛보기
