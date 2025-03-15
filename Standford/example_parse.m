clc; clear; close all;

%% (0) 로드 경로 지정 및 파일 경로에서 제목 문자열 생성
loadPath = 'G:\공유 드라이브\BSL_Onori\Cycling_tests\Processed_3\W7.mat';
[folderPath, fileName, ~] = fileparts(loadPath);
[~, folderName] = fileparts(folderPath);
plotTitle = sprintf('%s_%s_UDDS', folderName, fileName);

%% (1) 데이터 로드
load(loadPath);

% (사용자 환경에 맞게 변수명 수정)
time = t_full_vec_M1_NMC25degC;
curr = I_full_vec_M1_NMC25degC;
volt = V_full_vec_M1_NMC25degC;

%% (2) 구간별 인덱스 설정
% idx_0 : 맨 처음 데이터(에러 추정)
idx_0 = 1;  

% idx_1 : 38,000초 이하 (단, 맨 처음 idx_0 제외)
idx_1 = 2:length(time);
idx_1 = idx_1(time(idx_1) <= 38000);

% idx_15 : 38,000초 초과
idx_15 = find(time > 38000);

%% (3) 구조체 템플릿 및 결과 저장할 data 생성
data_line = struct('V', [], 'I', [], 't', [], 'step', [], 'time_reset', []);
data = repmat(data_line, 3, 1);

% ----- step=0 -----
data(1).V = volt(idx_0);
data(1).I = curr(idx_0);
data(1).t = time(idx_0);
data(1).step = 0;
data(1).time_reset = data(1).t - data(1).t(1);

% ----- step=1 -----
data(2).V = volt(idx_1);
data(2).I = curr(idx_1);
data(2).t = time(idx_1);
data(2).step = 1;
data(2).time_reset = data(2).t - data(2).t(1);

% ----- step=15 -----
data(3).V = volt(idx_15);
data(3).I = curr(idx_15);
data(3).t = time(idx_15);
data(3).step = 15;
data(3).time_reset = data(3).t - data(3).t(1);

%% (4) step=1 구간 내에서 추가 파싱 (16,17,18,19)
% --------------------------------------------------
% [1] rest 구간(전류 == 0)을 '16'으로 설정 (첫 번째 rest 구간 가정)
% [2] rest 구간보다 시간상 앞쪽 구간에서:
%     - 전류가 -1.3 ~ -1.1 사이로 20분(>=1200초) 이상 지속되는 부분을 '18' 
%       나머지(=그 이전/이후) 부분은 '17'
% [3] rest 구간 이후의 나머지 구간은 '19' 
% --------------------------------------------------

% 원본 step=1 정보
t1   = data(2).t;
I1   = data(2).I;
V1   = data(2).V;
dt1  = diff(t1);              % 시계열 간격 (비균일 샘플링 시 사용 가능)
idx1 = idx_1;                 % 전체 step=1의 절대 인덱스(원본 time배열 기준)

%% (4-1) rest(0A) 구간 찾기
% 전류가 정확히 0인 지점의 인덱스(조건에 따라 근사 0으로 설정 가능)
restLogical = (abs(I1) < 1e-12); 
restIdxRel  = find(restLogical);       % step=1 구간 내 '상대' 인덱스
restIdxAbs  = idx1(restIdxRel);        % 전체 데이터 기준 '절대' 인덱스

if isempty(restIdxRel)
    % 만약 rest 구간이 전혀 없다면
    warning('step=1 구간 내에 I=0(REST) 구간이 없습니다.');
    % 이후 로직 패스하거나, 다른 방식 처리
    idx_16_rel = []; idx_17_rel = 1:length(I1); 
    idx_18_rel = []; idx_19_rel = [];
else
    % rest 구간 중에서 '연속 구간'이 여러 개라면 여기서 처리 필요.
    % 예시는 "첫 번째 구간"만 쓰는 간단 버전
    %-------------------------------------------
    % 첫 번째 rest 구간 시작/끝 찾기
    diffIdx  = diff(restIdxRel);
    gapStart = [1; find(diffIdx>1)+1]; % rest 구간이 끊긴 지점
    % 일단 첫 번째 연속 구간만 추출
    firstStartRel = restIdxRel(gapStart(1));
    
    % 해당 구간의 끝 지점 찾기
    if length(gapStart) == 1
        % rest가 하나의 덩어리라면
        firstEndRel = restIdxRel(end);
    else
        firstEndRel = restIdxRel(gapStart(2)-1);
    end
    
    % 이 구간이 step=16
    idx_16_rel = firstStartRel : firstEndRel;
    
    % rest 구간 시작 전후로 쪼개기
    idx_preRest_rel = 1:(firstStartRel-1);     % rest 직전
    idx_postRest_rel = (firstEndRel+1):length(I1); % rest 이후
end

%% (4-2) rest '앞' 구간(= idx_preRest_rel)을 17,18로 쪼개기
%  - '전류가 -1.3 ~ -1.1 사이'로 >=1200초 이상 지속 구간을 18로
%  - 나머지는 17로.
idx_17_rel = [];
idx_18_rel = [];

if exist('idx_preRest_rel','var') && ~isempty(idx_preRest_rel)
    
    I_pre = I1(idx_preRest_rel);
    t_pre = t1(idx_preRest_rel);
    
    % --- -1.3 ~ -1.1 사이 구간 논리값
    c18_logical = (I_pre >= -1.3) & (I_pre <= -1.1);
    
    % --- 연속 구간 찾아서 '해당 구간의 시간 길이'가 1200초 이상인지 확인
    c18_idx = find(c18_logical);
    if isempty(c18_idx)
        % 해당 범위가 전혀 없으면 전부 17로
        idx_17_rel = idx_preRest_rel;
    else
        % 연속 구간 찾기
        diffC18 = diff(c18_idx);
        gapStartC18 = [1; find(diffC18>1)+1];
        
        found18 = false;
        for gi = 1:length(gapStartC18)
            thisStart = c18_idx(gapStartC18(gi));
            if gi == length(gapStartC18)
                thisEnd = c18_idx(end);
            else
                thisEnd = c18_idx(gapStartC18(gi+1)-1);
            end
            
            % 구간 시간 길이 검사
            durSec = t_pre(thisEnd) - t_pre(thisStart);
            
            if durSec >= 1200
                % 이 구간 전체를 18로 설정
                idx_18_rel = [idx_18_rel, thisStart:thisEnd];
                found18 = true;
            end
        end
        
        % 나머지는 17
        if found18
            idxNot18_rel = setdiff(idx_preRest_rel, idx_preRest_rel(idx_18_rel));
            idx_17_rel   = [idx_17_rel, idxNot18_rel];
        else
            % 20분 이상 구간 없으면 전부 17
            idx_17_rel = idx_preRest_rel;
        end
    end
end

%% (4-3) rest '이후' 구간은 전부 19
idx_19_rel = [];
if exist('idx_postRest_rel','var') && ~isempty(idx_postRest_rel)
    idx_19_rel = idx_postRest_rel;
end

%% (4-4) 각 구간별 최종 구조체 생성
% data(2)는 이제 더 세밀하게 나누므로 필요하다면 보존 or 제거
% 여기서는 data(2)를 살려두고, 새로 data(4)~data(7)에 저장

% step=16 (rest)
if ~isempty(idx_16_rel)
    data(4).V = V1(idx_16_rel);
    data(4).I = I1(idx_16_rel);
    data(4).t = t1(idx_16_rel);
    data(4).step = 16;
    data(4).time_reset = data(4).t - data(4).t(1);
else
    data(4) = data_line;
    data(4).step = 16; 
end

% step=17
if ~isempty(idx_17_rel)
    data(5).V = V1(idx_17_rel);
    data(5).I = I1(idx_17_rel);
    data(5).t = t1(idx_17_rel);
    data(5).step = 17;
    data(5).time_reset = data(5).t - data(5).t(1);
else
    data(5) = data_line;
    data(5).step = 17;
end

% step=18
if ~isempty(idx_18_rel)
    data(6).V = V1(idx_18_rel);
    data(6).I = I1(idx_18_rel);
    data(6).t = t1(idx_18_rel);
    data(6).step = 18;
    data(6).time_reset = data(6).t - data(6).t(1);
else
    data(6) = data_line;
    data(6).step = 18;
end

% step=19
if ~isempty(idx_19_rel)
    data(7).V = V1(idx_19_rel);
    data(7).I = I1(idx_19_rel);
    data(7).t = t1(idx_19_rel);
    data(7).step = 19;
    data(7).time_reset = data(7).t - data(7).t(1);
else
    data(7) = data_line;
    data(7).step = 19;
end

%% (5) 확인용 플롯
figure; hold on;

% 원래 step=1 (파싱 전)
plot(t1, I1, 'k-', 'DisplayName','step=1 (original)');
title('step=1 구간 세부 파싱');

% 파싱된 것들을 색상·마커 다르게 하여 플롯
if ~isempty(idx_16_rel), plot(t1(idx_16_rel), I1(idx_16_rel), 'ro', 'DisplayName','step=16 (rest)'); end
if ~isempty(idx_17_rel), plot(t1(idx_17_rel), I1(idx_17_rel), 'b.', 'DisplayName','step=17'); end
if ~isempty(idx_18_rel), plot(t1(idx_18_rel), I1(idx_18_rel), 'gx', 'DisplayName','step=18'); end
if ~isempty(idx_19_rel), plot(t1(idx_19_rel), I1(idx_19_rel), 'm.', 'DisplayName','step=19'); end

xlabel('Time (s)');
ylabel('Current (A)');
legend('Location','best');
xlim([t1(1), t1(end)]);


