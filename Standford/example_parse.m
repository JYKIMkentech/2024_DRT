clc; clear; close all;

%% (0) 로드 경로 지정 및 파일 경로에서 제목 문자열 생성
loadPath = 'G:\공유 드라이브\BSL_Onori\Cycling_tests\Processed_3\V5.mat';
[folderPath, fileName, ~] = fileparts(loadPath);
[~, folderName] = fileparts(folderPath);
plotTitle = sprintf('%s_%s_UDDS', folderName, fileName);

%% (1) 데이터 로드 + Arbin step 기준 1차 분할
load(loadPath);

% (사용자 환경에 맞게 변수명 수정)
time       = t_full_vec_M1_NMC25degC;
curr       = I_full_vec_M1_NMC25degC;
volt       = V_full_vec_M1_NMC25degC;
step_arbin = Step_Index_full_vec_M1_NMC25degC;

% 구조체 (V, I, t, step)로 관리
data_raw.V    = volt;
data_raw.I    = curr;
data_raw.t    = time;
data_raw.step = step_arbin;

% step 변화 인덱스
change_indices = [1; find(diff(step_arbin) ~= 0)+1; length(step_arbin)+1];
num_segments   = length(change_indices) - 1;

% 기본 템플릿
data_line = struct('V', [], 'I', [], 't', [], 'step', [], 'time_reset', []);

% Arbin step마다 잘라서 data에 저장
data = repmat(data_line, num_segments, 1);
for i = 1:num_segments
    idx_start = change_indices(i);
    idx_end   = change_indices(i+1) - 1;
    range     = idx_start:idx_end;
    
    data(i).V    = data_raw.V(range);
    data(i).I    = data_raw.I(range);
    data(i).t    = data_raw.t(range);
    data(i).step = data_raw.step(idx_start);
    data(i).time_reset = data(i).t - data(i).t(1);
end

%% (2) data(2)를 "연속된 전류=0 구간" + 그 이후 구간으로 분할
oldData = data;  % 백업

% data(1)은 그대로
data(1) = oldData(1);

% data(2) 나누기
I_2 = oldData(2).I;
V_2 = oldData(2).V;
t_2 = oldData(2).t;

% 전류=0인 인덱스
idx_zero = find(I_2 == 0);

if isempty(idx_zero)
    % 전류=0이 없다면 => 전부 data(2)에 할당, data(3)는 없음
    data(2) = oldData(2);
    data(2).step = 2;
    disp('data(2): 전류=0 구간이 없어 그대로 전체 할당');
else
    diff_idx_zero = diff(idx_zero);
    firstBreak = find(diff_idx_zero > 1, 1, 'first');
    
    if isempty(firstBreak)
        blockEnd = idx_zero(end);  % 전체가 0
    else
        blockEnd = idx_zero(firstBreak);
    end
    
    % 맨 처음 "0" 구간 → data(2)
    data(2).V = V_2(1:blockEnd);
    data(2).I = I_2(1:blockEnd);
    data(2).t = t_2(1:blockEnd);
    data(2).time_reset = data(2).t - data(2).t(1);
    data(2).step = 1;  % 전류=0 이므로 step=1 (임의)

    % 나머지 -> data(3)
    data(3).V = V_2(blockEnd+1:end);
    data(3).I = I_2(blockEnd+1:end);
    data(3).t = t_2(blockEnd+1:end);
    if ~isempty(data(3).t)
        data(3).time_reset = data(3).t - data(3).t(1);
    else
        data(3).time_reset = [];
    end
    data(3).step = 3;
end

%% (3) data(3)를 "I=0.05"에서 분할 → data(3) / data(4)
oldData3 = data(3);
I_3 = oldData3.I;
V_3 = oldData3.V;
t_3 = oldData3.t;

tolerance = 1e-4;
cutIdx = find(abs(I_3 - 0.05) < tolerance, 1, 'first');

if isempty(cutIdx)
    disp('data(3): I=0.05 못찾음 → 전체 유지, data(4)는 빈 구간');
    data(4).V = [];
    data(4).I = [];
    data(4).t = [];
    data(4).time_reset = [];
    data(4).step = [];
else
    data(3).V = V_3(1:cutIdx);
    data(3).I = I_3(1:cutIdx);
    data(3).t = t_3(1:cutIdx);
    data(3).time_reset = data(3).t - data(3).t(1);
    % data(3).step 유지
    
    data(4).V = V_3(cutIdx+1:end);
    data(4).I = I_3(cutIdx+1:end);
    data(4).t = t_3(cutIdx+1:end);
    if ~isempty(data(4).t)
        data(4).time_reset = data(4).t - data(4).t(1);
    else
        data(4).time_reset = [];
    end
    data(4).step = 3;  % 필요 시 다른 번호 사용
end

%% (4-1) data(4)에서 "전류=0" 구간 + 나머지로 분할 → data(4), data(5)
oldData4 = data(4);
I_4 = oldData4.I;
V_4 = oldData4.V;
t_4 = oldData4.t;

if isempty(I_4)
    disp('data(4)가 비어서, 분할할 내용이 없습니다.');
    data(5).V = [];
    data(5).I = [];
    data(5).t = [];
    data(5).time_reset = [];
    data(5).step = [];
else
    idx_zero_4 = find(I_4 == 0);
    if isempty(idx_zero_4)
        disp('data(4)에 전류=0 구간이 없어 그대로 유지합니다.');
        data(5).V = [];
        data(5).I = [];
        data(5).t = [];
        data(5).time_reset = [];
        data(5).step = [];
    else
        diff_zero_4 = diff(idx_zero_4);
        firstBreak4 = find(diff_zero_4 > 1, 1, 'first');
        
        if isempty(firstBreak4)
            blockEnd4 = idx_zero_4(end);
        else
            blockEnd4 = idx_zero_4(firstBreak4);
        end
        
        % data(4) = 맨 앞 연속된 0
        data(4).V = V_4(1:blockEnd4);
        data(4).I = I_4(1:blockEnd4);
        data(4).t = t_4(1:blockEnd4);
        if ~isempty(data(4).t)
            data(4).time_reset = data(4).t - data(4).t(1);
        else
            data(4).time_reset = [];
        end
        data(4).step = 4;
        
        % data(5) = 나머지
        data(5).V = V_4(blockEnd4+1:end);
        data(5).I = I_4(blockEnd4+1:end);
        data(5).t = t_4(blockEnd4+1:end);
        if ~isempty(data(5).t)
            data(5).time_reset = data(5).t - data(5).t(1);
        else
            data(5).time_reset = [];
        end
        data(5).step = 5;
    end
end

%% (4-2) data(5)를 "-1.22±0.01" 구간 + 나머지로 분할 → data(5), data(6)
oldData5 = data(5);

I_5 = oldData5.I;
V_5 = oldData5.V;
t_5 = oldData5.t;

tol_dis = 0.01;
lowBound = -1.22 - tol_dis;  % -1.23
highBound = -1.22 + tol_dis; % -1.21

idx_inRange = find(I_5 >= lowBound & I_5 <= highBound);

if isempty(idx_inRange)
    disp('data(5)에 -1.22±0.01 범위에 해당하는 전류가 없어, 그대로 유지. data(6)는 빈 구조체.');
    data(6).V = [];
    data(6).I = [];
    data(6).t = [];
    data(6).time_reset = [];
    data(6).step = [];
else
    diff_inRange = diff(idx_inRange);
    firstBreak_5 = find(diff_inRange > 1, 1, 'first');
    
    if isempty(firstBreak_5)
        blockEnd_5 = idx_inRange(end);  % 하나의 연속 덩어리
    else
        blockEnd_5 = idx_inRange(firstBreak_5);
    end
    
    % data(5) = 맨 앞 -1.22±0.01 구간
    data(5).V = V_5(1:blockEnd_5);
    data(5).I = I_5(1:blockEnd_5);
    data(5).t = t_5(1:blockEnd_5);
    if ~isempty(data(5).t)
        data(5).time_reset = data(5).t - data(5).t(1);
    else
        data(5).time_reset = [];
    end
    data(5).step = 13;  % 예: 13
    
    % 나머지 = data(6)
    data(6).V = V_5(blockEnd_5+1:end);
    data(6).I = I_5(blockEnd_5+1:end);
    data(6).t = t_5(blockEnd_5+1:end);
    if ~isempty(data(6).t)
        data(6).time_reset = data(6).t - data(6).t(1);
    else
        data(6).time_reset = [];
    end
    data(6).step = 14;
end

%% (4-3) data(6)을 "전류 차이가 2 이상으로 크게 바뀌는 첫 지점"에서 분할 → data(6), data(7)
%
%   - 예: data(6)의 전류가 -1.1 → (크게 변동) → +0.98 로 jump할 때,
%         diff가 2 이상이 되는 첫 번째 지점에서 분할
%
%   - abs(diff(I_6)) > 2 인 인덱스를 찾는다.
%   - 그중 첫 번째 지점 boundaryIdx를 경계로, 
%       data(6) = 1 ~ boundaryIdx
%       data(7) = boundaryIdx+1 ~ end
%     (MATLAB에서 diff(I_6)(k)는 I_6(k+1)-I_6(k)이므로 boundaryIdx+1이 실제 바뀌는 지점)

oldData6 = data(6);
I_6 = oldData6.I;
V_6 = oldData6.V;
t_6 = oldData6.t;

if length(I_6) < 2
    % 만약 data(6)에 데이터가 너무 적거나(길이<2) 비어 있다면 -> 분할 불가
    disp('data(6)의 길이가 2 미만이어서, 큰 전류 변동을 파악할 수 없습니다.');
    % data(7)는 빈 구간
    data(7).V = [];
    data(7).I = [];
    data(7).t = [];
    data(7).time_reset = [];
    data(7).step = [];
else
    dI_6 = abs(diff(I_6));  % 연속 시점간 전류 차이
    boundaryIdx = find(dI_6 > 2, 1, 'first');  % 차이가 2 초과되는 첫 지점
    
    if isempty(boundaryIdx)
        % 큰 변동이 전혀 없으면 => data(6) 그대로, data(7) 비움
        disp('data(6)에서 전류 차이가 2 이상인 지점을 찾지 못했습니다. => data(7)는 빈 구간');
        data(7).V = [];
        data(7).I = [];
        data(7).t = [];
        data(7).time_reset = [];
        data(7).step = [];
    else
        % boundaryIdx ~ boundaryIdx+1 사이에서 전류 급변
        % data(6) = 1 ~ boundaryIdx
        data(6).V = V_6(1:boundaryIdx);
        data(6).I = I_6(1:boundaryIdx);
        data(6).t = t_6(1:boundaryIdx);
        if ~isempty(data(6).t)
            data(6).time_reset = data(6).t - data(6).t(1);
        else
            data(6).time_reset = [];
        end
        % step 번호는 그대로 사용하거나 원하는 대로 지정
        % data(6).step = 6;  

        % data(7) = boundaryIdx+1 ~ end
        data(7).V = V_6(boundaryIdx+1:end);
        data(7).I = I_6(boundaryIdx+1:end);
        data(7).t = t_6(boundaryIdx+1:end);
        if ~isempty(data(7).t)
            data(7).time_reset = data(7).t - data(7).t(1);
        else
            data(7).time_reset = [];
        end
        data(7).step = 7;  % 원하는 번호
    end
end

%% (5) 최종 확인
disp('==== 최종 data 구조체 요약 ====');
for i = 1:length(data)
    fprintf('data(%d): 길이=%d, step=', i, length(data(i).I));
    if isempty(data(i).step)
        disp('[] (빈 구간)');
    else
        disp(data(i).step);
    end
end

%% figure
figure(1)
plot(vertcat(data(4).t, data(5).t, data(6).t), vertcat(data(4).I, data(5).I, data(6).I));
xlabel('time')
ylabel('current')

figure(2)
plot(vertcat(data(4).t, data(5).t, data(6).t,data(7).t), vertcat(data(4).I, data(5).I, data(6).I,data(7).I));
%xlim([31400 31600]);
xlabel('time')
ylabel('current')












