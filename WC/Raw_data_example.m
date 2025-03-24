%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 전체 코드 예시
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;

%% (1) CSV 파일 경로 및 옵션 설정
filename = 'G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_059.csv';
opts = detectImportOptions(filename, 'VariableNamingRule','preserve');
dataTable = readtable(filename, opts);

%% (2) Current 부호(C, R, D)로 스텝을 구분할지, 아니면 State로 구분할지 결정
%   - useType = true  => I>0 => 'C', I=0 => 'R', I<0 => 'D' 로 스텝 구분
%   - useType = false => 테이블의 'State' 열이 바뀔 때마다 스텝 구분
useType = false;

if useType
    % (2-1) Current 부호(C, R, D)로 구분
    %       'Normalized Current (C-rate)' 열 기준
    currentData = dataTable.("Normalized Current (C-rate)");
    
    % 새 열 'type'을 추가 (문자형 벡터)
    dataTable.type = repmat('R', [height(dataTable), 1]); % 기본값 R로 초기화
    dataTable.type(currentData > 0) = 'C';  % 충전
    dataTable.type(currentData < 0) = 'D';  % 방전
    
    % step을 부여할 기준 열 이름 지정
    stepColumnName = 'type'; 
else
    % (2-2) State 열이 이미 존재한다고 가정
    stepColumnName = 'State';
end

%% (3) 스텝 인덱스 부여
% step 인덱스 열(stepIndex)을 추가: 이전 행과 달라지면 +1
nData = height(dataTable);
dataTable.stepIndex = zeros(nData, 1);
dataTable.stepIndex(1) = 1;

for i = 2:nData
    if ~strcmp(dataTable.(stepColumnName)(i), dataTable.(stepColumnName)(i-1))
        dataTable.stepIndex(i) = dataTable.stepIndex(i-1) + 1;
    else
        dataTable.stepIndex(i) = dataTable.stepIndex(i-1);
    end
end

%% (4) 테이블 열 이름 -> 구조체 필드 이름 변환
% 공백, 괄호 등이 포함된 원본 열 이름을 MATLAB 유효 필드 이름으로 변환
varNames         = dataTable.Properties.VariableNames;     % 원본 열 이름
validFieldNames  = matlab.lang.makeValidName(varNames);    % 유효한 필드 이름

%% (5) 고유한 step 목록 파악 및 구조체 배열 생성
uniqueSteps = unique(dataTable.stepIndex);
numSteps    = length(uniqueSteps);

% (5-1) 구조체 템플릿(빈 필드) 만들기
data_line = struct();
for v = 1:numel(varNames)
    data_line.(validFieldNames{v}) = [];
end

% (5-2) 구조체 배열 초기화
dataStruct = repmat(data_line, numSteps, 1);

% (5-3) 각 스텝 구간별로 구조체에 할당
for i_step = 1:numSteps
    % 현재 스텝에 해당하는 행 인덱스
    rowsInStep = (dataTable.stepIndex == uniqueSteps(i_step));
    
    % 변환된 필드 이름마다, 해당 구간의 데이터를 구조체에 저장
    for v = 1:numel(varNames)
        dataStruct(i_step).(validFieldNames{v}) = dataTable.(varNames{v})(rowsInStep);
    end
end

%% (6) 확인 및 간단한 예시
disp('=== 첫 번째 스텝 구조체 예시 ===');
disp(dataStruct(1));

% 예) 첫 번째 스텝의 "Volts" 배열 확인
volts_step1 = dataStruct(1).Volts;
disp('=== 첫 번째 스텝의 Volts ===');
disp(volts_step1);

% 예) 첫 번째 스텝의 "NormalizedCurrentCrate" (C-rate) 확인
if isfield(dataStruct, 'NormalizedCurrentCrate')
    current_step1 = dataStruct(1).NormalizedCurrentCrate;
    disp('=== 첫 번째 스텝의 Current (C-rate) ===');
    disp(current_step1);
end

%% (7) 스텝별 플롯 (선택)
% 예: 각 스텝별로 전압-시간 그래프를 그려보고 싶을 때
figure('Name','Step별 전압 vs 시간 예시','NumberTitle','off'); hold on;
colors = lines(numSteps);  % 색상 팔레트

for i_step = 1:numSteps
    tData = dataStruct(i_step).TestSec;   % "Test (Sec)" -> "TestSec"
    vData = dataStruct(i_step).Volts;     % "Volts"
    plot(tData, vData, 'Color', colors(i_step,:), 'DisplayName',['Step ' num2str(i_step)]);
end
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Voltage vs. Time (각 Step 구간 구분)');
legend('show');
hold off;
