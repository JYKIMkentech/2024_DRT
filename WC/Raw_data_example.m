clear; clc; close all;

%% (1) 파일 경로 설정
filename = 'G:\공유 드라이브\BSL_WC\Publishing_data_raw_data_cell_059.csv';

%% (2) 파일 이름에서 cell 번호 추출
cellNumTokens = regexp(filename, 'cell_(\d+)', 'tokens');
if ~isempty(cellNumTokens)
    cellNumStr = cellNumTokens{1}{1};  % 예: '059'
else
    cellNumStr = 'unknown';
end

%% (3) Import Options 감지 및 확인
opts = detectImportOptions(filename, 'VariableNamingRule','preserve');

% 혹시 열 이름/자료형이 잘못 인식되면 수정
opts = setvartype(opts, 'Step', 'double');        
opts = setvartype(opts, 'Full Step #', 'string'); 

%% (4) 테이블 읽기 (원본 데이터를 data1으로 명명)
data1 = readtable(filename, opts);

%% (5) Step 열을 기준으로 데이터 쪼개기
stepVec  = data1.Step;
idxChange = find(diff(stepVec) ~= 0);
nSeg = length(idxChange) + 1;
dataCell = cell(nSeg, 1);

startIdx = 1;
for i = 1:length(idxChange)
    endIdx = idxChange(i);
    dataCell{i} = data1(startIdx:endIdx, :);
    startIdx = endIdx + 1;
end
dataCell{end} = data1(startIdx:end, :);

%% (6) cell로 잘린 data들을 구조체로 변환
%     - time, voltage, current 등은 전체 파형(벡터)을 그대로 저장
%     - cyc, step, state, loop3는 unique() 적용해서 대표값을 저장
%     - step_time 필드 추가

% 미리 구조 정의 (필드는 상황에 맞게 늘리거나 바꾸세요)
dataTemplate = struct( ...
    'time', [], ...
    'voltage', [], ...
    'current', [], ...
    'cyc', [], ...
    'step', [], ...
    'state', [], ...
    'loop3', [], ...
    'step_time', [] );

% 구조체 배열(data) 초기화
data = repmat(dataTemplate, nSeg, 1);

for i = 1:nSeg
    thisTbl = dataCell{i};
    
    % (필드1) time, voltage, current 등
    data(i).time    = thisTbl.("Test (Sec)");
    data(i).voltage = thisTbl.Volts;
    data(i).current = thisTbl.("Normalized Current (C-rate)");

    % (필드2) 해당 구간에서의 고유 cyc, step, state, loop3
    data(i).cyc   = unique(thisTbl.("Cyc#"));
    data(i).step  = unique(thisTbl.Step);
    data(i).state = unique(thisTbl.State);
    data(i).loop3 = unique(thisTbl.Loop3);
    
    % (필드3) step_time 추가
    data(i).step_time = thisTbl.("Step (Sec)");
    
    % 필요하다면 table에 있던 다른 열들도 구조체 필드로 추가...
end

%% (7) 구조체를 MAT 파일로 저장 (파일 이름에 cell 번호 반영)
saveFilename = fullfile('G:\공유 드라이브\BSL_WC', ['cell_', cellNumStr, '_data.mat']);
save(saveFilename, 'data');

