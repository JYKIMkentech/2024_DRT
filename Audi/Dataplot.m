%% analyze_folder2.m
% -------------------------------------------------------------------------
%  Folder 2 (Drive) 세션의 Raw.mat을 불러와
%  Current / Voltage / SoC / Temperature 4개 신호를 개별 Figure로 표시하고
%  간단 통계만 콘솔에 출력한다. (저장 X)
% -------------------------------------------------------------------------

clc; clear; close all;

%% 1) 파일 경로 설정 --------------------------------------------------------
matFile = 'G:\공유 드라이브\BSL_Audi\Drive\Folder2\Raw.mat';   % 필요 시 수정
if ~isfile(matFile)
    error('Raw.mat 파일을 찾을 수 없습니다:\n%s', matFile);
end

%% 2) 데이터 로드 ----------------------------------------------------------
load(matFile);                 % struct 변수(예: Raw) 하나가 들어 있다고 가정
varsInMat = whos;
data = eval(varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name);

%% 3) 필드 추출 ------------------------------------------------------------
tCurr = data.TimeCurr(:);   I   = data.Curr(:);
tVolt = data.TimeVolt(:);   V   = data.Volt(:);
tSoC  = data.TimeSoC(:);    soc = data.SoC(:);
tTemp = data.TimeTemp(:);   T   = data.Temp(:);

%% 4) 4개 개별 Figure ------------------------------------------------------
% (1) Current
figure('Name','Current');
plot(tCurr, I); grid on;
xlabel('Time  [s]'); ylabel('Current  [A]');
title('Pack Current');

% (2) Voltage
figure('Name','Voltage');
plot(tVolt, V); grid on;
xlabel('Time  [s]'); ylabel('Voltage  [V]');
title('Pack Voltage');

% (3) SoC
figure('Name','SoC');
plot(tSoC, soc); grid on;
xlabel('Time  [s]'); ylabel('SoC  [%]');
title('State of Charge');

% (4) Temperature
figure('Name','Temperature');
plot(tTemp, T); grid on;
xlabel('Time  [s]'); ylabel('Temperature  [°C]');
title('Pack Temperature');

%% 5) 기본 통계 콘솔 출력 ---------------------------------------------------
durDrive_h   = (max(tCurr) - min(tCurr)) / 3600;   % 총 시간[h]
charge_Ah    = trapz(tCurr, I) / 3600;             % 누적 Ah
energy_Wh    = trapz(tVolt, V .* I) / 3600;        % 누적 Wh

fprintf('\n=== Folder 2 – Drive 세션 요약 ===\n');
fprintf('주행 시간          : %.2f h\n', durDrive_h);
fprintf('누적 전류(Ah)      : %.2f Ah (부호 기준)\n', charge_Ah);
fprintf('추정 소모 에너지   : %.1f Wh (V·I 적분)\n', energy_Wh);
fprintf('최대 전류|전압|온도 : %.1f A | %.1f V | %.1f °C\n', ...
        max(abs(I)), max(V), max(T));
