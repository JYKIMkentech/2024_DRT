clear; clc; close all;

%% (1) 파일 경로 설정
filename = 'G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_059.csv';

%% (2) Import Options 감지 및 확인
%  'VariableNamingRule','preserve'를 사용하면 원본 열 이름(공백, 괄호 포함)을 그대로 유지합니다.
opts = detectImportOptions(filename, 'VariableNamingRule','preserve');

% 추론된 변수(열) 이름 및 자료형을 확인
disp('=== Variable Names ===');
disp(opts.VariableNames);
disp('=== Variable Types ===');
disp(opts.VariableTypes);

%% (3) 자료형이 잘못 인식된 열이 있으면 수정
% 실제 테이블에 존재하는 정확한 열 이름을 써야 함
% 예: 'Full Step #'이 datetime으로 잘못 인식되어 있으면 문자열 등으로 강제 지정
opts = setvartype(opts, 'Step', 'double');        
opts = setvartype(opts, 'Full Step #', 'string'); % "Full Step#Loop"가 아니라 "Full Step #"

%% (4) 테이블 읽기
data = readtable(filename, opts);

%% (5) (선택) 열 이름을 편하게 바꾸기
% 필요하다면 data.Properties.VariableNames{...}를 이용해 
% "Test (Sec)" 등을 "Test_Sec"처럼 바꿀 수 있습니다.

%% (6) 필요한 열 불러오기 (원본 열 이름 그대로 접근)
time    = data.("Test (Sec)");
voltage = data.Volts;
current = data.("Normalized Current (C-rate)");

%% (7) 플롯 그리기
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



%xlim([723031 723500]);
%xlim([723031 773500]);