clc; clear; close all;

%% (0) 데이터 로드
loadPath = 'G:\공유 드라이브\BSL_Onori\Cycling_tests\Processed_3\W7.mat';
load(loadPath);

% 사용자 환경에 맞게 변수명 조정
time = t_full_vec_M1_NMC25degC;
volt = V_full_vec_M1_NMC25degC;
curr = I_full_vec_M1_NMC25degC;

%% (1) step 시퀀스 정의
%  예: 0(전류=0, 전압=0) -> 1(전류=0) -> 2(CC충전) -> ... 등
%  필요에 맞게 늘리거나 줄이세요.
stepSequence = [ ...
    0,  ...  % step 0: i=0 AND v=0
    1,  ...  % step 1: i=0 (휴지)
    2,  ...  % step 2: CC 충전(+1.2~+1.3 A)
    3,  ...  % step 3: CV충전 (예: i>0, i<1.2)
    4,  ...  % step 4: 다시 휴지(i=0)
    13, ...  % step 13: CC방전(-1.3~-1.2)
    14  ...  % step 14: UDDS (i< -1.2, 등등)
];

%% (2) 파싱 메커니즘
N = length(time);
idxStart  = 1;       % 현재 step을 찾기 시작할 인덱스
stepCount = 0;       % 구간(스텝) 개수
data      = [];      % 결과 저장할 구조체 배열

seqPos = 1;          % stepSequence에서 몇 번째 step을 보고 있는가?

while idxStart <= N
    if seqPos > length(stepSequence)
        % stepSequence 끝까지 다 돌면 종료하거나,
        % seqPos=1로 다시 돌아가 반복하도록 할 수도 있음(필요에 따라)
        break;
    end
    
    thisStep = stepSequence(seqPos);
    stepCount = stepCount + 1;
    
    % (A) 스텝별 조건 정의 (switch-case)
    switch thisStep
        case 0
            % step 0: 전류=0 AND 전압=0
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) ( (i==0) && (v==0) ));
            
        case 1
            % step 1: 전류=0 (보통 휴지구간)
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) (i==0)&& (v==~0));
            
        case 2
            % CC 충전: +1.2~+1.3 A
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) ( i>=1.2 && i<=1.3 ));
            
        case 3
            % CV 충전 예시(전류가 0보다 크고 1.2보다 작은 구간)
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) ( i>0 && i<1.2 ));
            
        case 4
            % 다시 휴지(전류=0)
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) (i==0));
            
        case 13
            % CC 방전: -1.3 ~ -1.2 A
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) ( i>=-1.3 && i<=-1.2 ));
            
        case 14
            % UDDS 방전 예시: 그보다 좀 더 다양한 음전류, 필요시 범위 조정
            [segIdxEnd] = grabSegment(curr, volt, time, idxStart, ...
                @(i,v) ( i< -1.2 ));
            
        otherwise
            % 미정의 스텝
            segIdxEnd = N;
            disp('알 수 없는 스텝 -> 남은 데이터는 전부 마지막으로 저장');
    end
    
    % (B) 유효 구간 존재 여부 확인
    if segIdxEnd <= idxStart
        fprintf('No valid segment found (step=%d). Parsing stopped.\n', thisStep);
        break;
    end
    
    % (C) data 구조체에 저장
    segRange = idxStart : segIdxEnd;
    data(stepCount).step       = thisStep;
    data(stepCount).t          = time(segRange);
    data(stepCount).I          = curr(segRange);
    data(stepCount).V          = volt(segRange);
    data(stepCount).time_reset = data(stepCount).t - data(stepCount).t(1);
    
    % (D) 다음 step으로 이동
    idxStart = segIdxEnd + 1;
    seqPos   = seqPos + 1;
end

%% (3) 결과 확인
fprintf('총 %d 개 스텝 구간을 찾았습니다.\n', length(data));

if ~isempty(data)
    for k = 1:length(data)
        fprintf('\n--- data(%d) ---\n', k);
        fprintf(' step = %d\n', data(k).step);
        fprintf(' 데이터 길이 = %d\n', length(data(k).t));
        fprintf(' 전류 범위: %.3f ~ %.3f A\n', min(data(k).I), max(data(k).I));
        fprintf(' 전압 범위: %.3f ~ %.3f V\n', min(data(k).V), max(data(k).V));
    end
end

%% (4) 예시 그래프
if length(data) >= 1
    figure; hold on;
    plot(data(1).t, data(1).I, 'DisplayName','I');
    plot(data(1).t, data(1).V, 'DisplayName','V');
    xlabel('Time (s)'); ylabel('Current (A) / Voltage (V)');
    legend('show');
    title(sprintf('Parsed Step #%d, (step=%d)',1,data(1).step));
end


%% (5) grabSegment 함수
function [endIndex] = grabSegment(I, V, T, startIndex, condFn)
% grabSegment:
%   startIndex부터 시작해서, (I(k), V(k))가 condFn(...)=true를
%   만족하는 지점을 연속적으로 쭉 찾다가, 조건이 거짓이 되는 순간 멈춤.
%
%   마지막으로 true였던 지점을 endIndex로 반환.

N = length(I);
k = startIndex;
while k <= N
    if ~condFn(I(k), V(k))
        break;
    end
    k = k + 1;
end
endIndex = k - 1;
end



