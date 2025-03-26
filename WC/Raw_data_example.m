clear; clc; close all;

%% (1) 파일 경로 설정
filename = 'G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_059.csv';

%% (2) Import Options 감지 및 확인
opts = detectImportOptions(filename, 'VariableNamingRule','preserve');

disp('=== Variable Names ===');
disp(opts.VariableNames);
disp('=== Variable Types ===');
disp(opts.VariableTypes);

%% (3) 자료형이 잘못 인식된 열이 있으면 수정
opts = setvartype(opts, 'Step', 'double');        
opts = setvartype(opts, 'Full Step #', 'string'); 

%% (4) 테이블 읽기 (원본 데이터를 data1으로 명명)
data1 = readtable(filename, opts);

%% (5) 열 이름을 편하게 바꾸거나 필요한 열만 가져올 수도 있음(선택)
% 예) data1.Properties.VariableNames{'Test (Sec)'} = 'Test_Sec';
%     ...

%% (6) 예시로 시간/전압/전류를 불러오기
time    = data1.("Test (Sec)");
voltage = data1.Volts;
current = data1.("Normalized Current (C-rate)");

%% (7) 간단한 플롯
figure;
yyaxis left
plot(time, voltage, 'b-');
ylabel('Voltage (V)');

yyaxis right
plot(time, current, 'r-');
ylabel('Current (C-rate)');

xlabel('Time (s)');
title('Voltage and Current vs. Time');
xlim([0 1000000]);

%% (8) Step 번호가 바뀌는 지점을 기준으로 data1을 쪼개어, 각각을 data라는 셀 배열에 저장
%  - 연속 구간 단위로 잘리는 것이므로, Step 번호가 다시 동일해지더라도
%    그 사이에 다른 Step이 들어갔다면 새로운 구간으로 분리됩니다.

% Step 열을 벡터로 추출
stepVec = data1.Step;

% 연속된 Step 번호가 달라지는 인덱스 찾기
idxChange = find(diff(stepVec) ~= 0);

% 잘린 결과를 넣을 셀 배열(data)을 준비
data = cell(length(idxChange)+1, 1);

% 첫 구간 시작 인덱스
startIdx = 1;

for i = 1:length(idxChange)
    endIdx = idxChange(i);
    data{i} = data1(startIdx:endIdx, :);  % 구간을 잘라서 저장
    startIdx = endIdx + 1;
end

% 마지막 구간 처리
data{end} = data1(startIdx:end, :);

%% 이제 data{1}, data{2}, ... 식으로 접근 가능
% 예) data{1} 안에는 Step이 연속으로 같은 부분(예: 모두 1)이 들어있습니다.
