%% analyze_folder.m
% -------------------------------------------------------------------------
%  Drive 세션의 Raw.mat을 불러와
%  Current / Voltage / SoC / Temperature 4개 신호를 개별 Figure로 표시하고
%  간단 통계만 콘솔에 출력한다. (저장 X)
% -------------------------------------------------------------------------

clc; clear; close all;

%% 0) 폴더 번호 입력 --------------------------------------------------------
validFolders = [2, 4, 6, 8, 10, 12, 14, 16];

while true
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n\n', folderNum);
end

%% 1) 파일 경로 설정 --------------------------------------------------------
matFile = sprintf('G:\\공유 드라이브\\BSL_Audi\\Drive\\Folder%d\\Raw.mat', folderNum);

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
figure('Name', sprintf('Current – Folder %d', folderNum));
plot(tCurr, I); grid on;
xlabel('Time  [s]'); ylabel('Current  [A]');
xlim([408500 410200])
title('Pack Current');

% figure('Name', sprintf('Voltage – Folder %d', folderNum));
% plot(tVolt, V); grid on;
% xlabel('Time  [s]'); ylabel('Voltage  [V]');
% title('Pack Voltage');
% 
figure('Name', sprintf('SoC – Folder %d', folderNum));
plot(tSoC, soc); grid on;
xlabel('Time  [s]'); ylabel('SoC  [%]');
title('State of Charge');
xlim([408500 410200])

% figure('Name', sprintf('Temperature – Folder %d', folderNum));
% plot(tTemp, T); grid on;
% xlabel('Time  [s]'); ylabel('Temperature  [°C]');
% title('Pack Temperature');

%% 5) 기본 통계 콘솔 출력 ---------------------------------------------------
durDrive_h   = (max(tCurr) - min(tCurr)) / 3600;   % 총 시간[h]
charge_Ah    = trapz(tCurr, I) / 3600;             % 누적 Ah
energy_Wh    = trapz(tVolt, V .* I) / 3600;        % 누적 Wh

fprintf('\n=== Folder %d – Drive 세션 요약 ===\n', folderNum);
fprintf('주행 시간          : %.2f h\n', durDrive_h);
fprintf('누적 전류(Ah)      : %.2f Ah (부호 기준)\n', charge_Ah);
fprintf('추정 소모 에너지   : %.1f Wh (V·I 적분)\n', energy_Wh);
fprintf('최대 전류|전압|온도 : %.1f A | %.1f V | %.1f °C\n', ...
        max(abs(I)), max(V), max(T));

