%% analyze_drive_folder.m
% -------------------------------------------------------------------------
%  Audi Drive 데이터 (Raw.mat) • 전류/전압/SoC 시각화 + Trip 경계 표시
%  Trip 구간: Δt 점프(>500 s) 양쪽을 경계로 정의
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
load(matFile);  % Raw.mat = struct 한 개
varsInMat = whos;
data      = eval(varsInMat(find(strcmp({varsInMat.class},'struct'),1)).name);

%% 3) 필드 추출 ------------------------------------------------------------
tCurr = data.TimeCurr(:);
I     = data.Curr(:);

tVolt = data.TimeVolt(:);
V     = data.Volt(:);

tSoC  = data.TimeSoC(:);
soc   = data.SoC(:);

%% 3.1) 시간 벡터 비교 ------------------------------------------------------
% tCurr와 tVolt가 동일한지, 길이는 같은지, 차이가 있는 인덱스는 몇 개인지 확인

% 1) 길이 비교
if numel(tCurr) ~= numel(tVolt)
    fprintf('⚠️ 벡터 길이가 다릅니다: tCurr=%d, tVolt=%d\n', numel(tCurr), numel(tVolt));
else
    % 2) 차이 계산
    dt_diff = tCurr - tVolt;
    
    % 3) 0이 아닌 차이 인덱스 찾기
    idx = find(dt_diff ~= 0);
    if isempty(idx)
        disp('✅ tCurr와 tVolt는 완전히 동일합니다.');
    else
        fprintf('⚠️ %d개의 불일치(차이≠0)가 발견되었습니다.\n', numel(idx));
        % (옵션) 처음 몇 개의 차이값 살펴보기
        nshow = min(10, numel(idx));
        fprintf('   첫 %d개 인덱스와 차이값:\n', nshow);
        for k = 1:nshow
            fprintf('     idx=%d: tCurr=%.6f, tVolt=%.6f, diff=%.6f\n', ...
                    idx(k), tCurr(idx(k)), tVolt(idx(k)), dt_diff(idx(k)));
        end
    end
end
