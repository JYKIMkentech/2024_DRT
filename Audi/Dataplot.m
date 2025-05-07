%% analyze_folder.m
% -------------------------------------------------------------------------
%  • Drive 세션(Folder k)의 Raw.mat을 로드하여
%    - Current / SoC 신호 시각화
%    - 주행 통계 출력
%    - |I|≈0 A 상태가 1200 s 이상 지속되는 “Rest” 구간 탐색
%      ▸ [startIdx endIdx]·Δt 콘솔 출력
%      ▸ 전류 그래프에 시작/끝 지점을 빨간 ● 로 표시
%
%  작성/수정: 2025‑05‑07
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
matFile = sprintf('G:\\공유 드라이브\\BSL_Audi\\Drive\\Folder%d\\Raw.mat', folderNum);

%% 2) 데이터 로드 ----------------------------------------------------------
load(matFile);                               % Raw.mat 안에는 struct 1개만 있다고 가정
varsInMat = whos;
data      = eval(varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name);

%% 3) 필드 추출 ------------------------------------------------------------
tCurr = data.TimeCurr(:);   I   = data.Curr(:);
tVolt = data.TimeVolt(:);   V   = data.Volt(:);
tSoC  = data.TimeSoC(:);    soc = data.SoC(:);
tTemp = data.TimeTemp(:);   T   = data.Temp(:);

%% 4) 전류 & SoC 플롯 ------------------------------------------------------
figCurr = figure('Name', sprintf('Current – Folder %d', folderNum));
hLine   = plot(tCurr, I, 'b'); grid on; hold on;
xlabel('Time  [s]'); ylabel('Current  [A]');
title('Pack Current');

figure('Name', sprintf('SoC – Folder %d', folderNum));
plot(tSoC, soc, 'b'); grid on;
xlabel('Time  [s]'); ylabel('SoC  [%]');
title('State of Charge');

%% 5) 주행 통계 ------------------------------------------------------------
durDrive_h = (max(tCurr) - min(tCurr)) / 3600;        % 총 시간[h]
charge_Ah  = trapz(tCurr, I) / 3600;                  % 누적 Ah
energy_Wh  = trapz(tVolt, V .* I) / 3600;             % 누적 Wh

fprintf('\n=== Folder %d – Drive 세션 요약 ===\n', folderNum);
fprintf('주행 시간          : %.2f h\n', durDrive_h);
fprintf('누적 전류(Ah)      : %.2f Ah (부호 유지)\n', charge_Ah);
fprintf('추정 소모 에너지   : %.1f Wh (V·I 적분)\n', energy_Wh);
fprintf('최대 전류|전압|온도 : %.1f A | %.1f V | %.1f °C\n', ...
        max(abs(I)), max(V), max(T));

%% 6) Rest 구간 탐색 --------------------------------------------------------
I_eps       = 1e-3;            % 3전류 ≈ 0" 허용 오차 [A]
minRestDur  = 1200;            % 최소 Rest 지속 시간 [s]

isRest      = abs(I) <= I_eps;
dRest       = diff([false; isRest; false]);
startIdxAll = find(dRest == 1);           % Rest 시작 인덱스
endIdxAll   = find(dRest == -1) - 1;      % Rest 종료 인덱스

restDurAll  = tCurr(endIdxAll) - tCurr(startIdxAll);
keep        = restDurAll >= minRestDur;   % 1200 s 이상 지속되는 구간만

restSegments = [startIdxAll(keep) endIdxAll(keep)];
restDur      = restDurAll(keep);

%% 7) 전류 그래프에 빨간 ● 표시 -------------------------------------------
if ~isempty(restSegments)
    figure(figCurr); hold on;                 % 전류 플롯 다시 활성화
    restT = [tCurr(restSegments(:,1)); tCurr(restSegments(:,2))];
    restI = [I(restSegments(:,1));     I(restSegments(:,2))];
    hScat = scatter(restT, restI, 40, 'r', 'filled');
    legend([hLine hScat], {'Current', 'Rest start/end'}, 'Location', 'best');
end

%% 8) Rest 구간 정보 콘솔 출력 --------------------------------------------
if isempty(restSegments)
    fprintf('Rest 구간(Δt ≥ %d s) 없음.\n', minRestDur);
else
    fprintf('\n--- Rest 구간 (|I|≤%.1e A & Δt≥%d s) ---------------------------\n', ...
            I_eps, minRestDur);
    fprintf(' idxStart   idxEnd     Δt[s]\n');
    for k = 1:size(restSegments,1)
        fprintf('%9d %9d  %7.0f\n', ...
                restSegments(k,1), restSegments(k,2), restDur(k));
    end
end

