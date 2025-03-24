clc; clear; close all;

%% 1. Python 모듈 임포트 및 pickle 파일 로드
py.importlib.import_module('pickle');

% 파일 경로 설정 (백슬래시 두 번 혹은 슬래시 사용)
filePath = 'G:/공유 드라이브/BSL_WC/Publishing_data_diagnostic_capacities.pkl';

% 바이너리 읽기 모드('rb')로 파일 오픈 후, pickle로 DataFrame 로드
fid = py.open(filePath, 'rb');
data = py.pickle.load(fid);

disp(data)  % DataFrame 구조 확인 (옵션)

%% 2. DataFrame → MATLAB 변환
% (A) 인덱스( (cell, cycle) )와 값(9개 컬럼)을 MATLAB cell/배열로 변환
pyIndex = cell(py.list(data.index.tolist()));   % 각 요소: Python tuple (예: {'cell_003', 1.0})
pyValues = cell(py.list(data.values.tolist())); % 각 행의 9개 데이터 (Python list)

nRows = length(pyIndex);
cellNames = cell(nRows,1);
cycleNumbers = zeros(nRows,1);

% (B) (cell, cycle) 분리 추출
for i = 1:nRows
    idxTuple = pyIndex{i};                 % 예: {'cell_003', 1.0}
    cellNames{i} = char(idxTuple{1});      % 'cell_003'
    cycleNumbers(i) = double(idxTuple{2}); % 1.0
end

% (C) 9개 컬럼 데이터를 double 배열로 변환
nCols = length(pyValues{1});  % 보통 9
numData = zeros(nRows, nCols);
for i = 1:nRows
    rowData = pyValues{i};                 % Python list
    numData(i,:) = cellfun(@double, cell(rowData));
end

%% 3. 각 cell별로 묶어서 저장: rawStruct (필드 = cell_001, cell_002, ...)
uniqueCells = unique(cellNames);  % 고유 cell 이름들
nCells = length(uniqueCells);

rawStruct = struct();  % 각 필드에 cell별 데이터 저장
for i = 1:nCells
    cName = uniqueCells{i};
    idx = strcmp(cellNames, cName);  % 이 cell에 해당하는 행
    rawStruct.(cName).Cycle                = cycleNumbers(idx);
    rawStruct.(cName).C40_charge_CC        = numData(idx, 1);
    rawStruct.(cName).C40_charge_CCCV      = numData(idx, 2);
    rawStruct.(cName).C40_discharge_CC     = numData(idx, 3);
    rawStruct.(cName).C40_discharge_CCCV   = numData(idx, 4);
    rawStruct.(cName).C2_charge_CC         = numData(idx, 5);
    rawStruct.(cName).C2_charge_CCCV       = numData(idx, 6);
    rawStruct.(cName).C2_discharge_CC      = numData(idx, 7);
    rawStruct.(cName).C2_discharge_CCCV    = numData(idx, 8);
    rawStruct.(cName).Normalized_Cumulative= numData(idx, 9);
end

% 이 시점에서 rawStruct를 클릭하면,
%  ├─ cell_001
%  ├─ cell_002
%  ├─ ...
% 와 같이 필드별로 분리되어 있는 구조체입니다.

%% 4. 모든 cell과 cycle을 한 ‘세로’에 이어붙여 “표”처럼 만들기
%   => resultStruct (Nx1 구조체 배열)
%      열(column)은 {'Cell','Cycle','C40_charge_CC', ... 'Normalized_Cumulative'}
%      행(row)은 모든 (cell, cycle) 조합

cellFields = fieldnames(rawStruct);  % 예: {'cell_001'; 'cell_002'; ...}
nTotal = 0;
for i = 1:length(cellFields)
    nTotal = nTotal + length(rawStruct.(cellFields{i}).Cycle);
end

% 미리 Nx1 크기의 구조체 배열 resultStruct 할당
resultStruct(nTotal,1).Cell = '';  % 마지막 인덱스까지 미리 잡아둠
resultStruct(nTotal,1).Cycle = 0;
resultStruct(nTotal,1).C40_charge_CC = 0;
resultStruct(nTotal,1).C40_charge_CCCV = 0;
resultStruct(nTotal,1).C40_discharge_CC = 0;
resultStruct(nTotal,1).C40_discharge_CCCV = 0;
resultStruct(nTotal,1).C2_charge_CC = 0;
resultStruct(nTotal,1).C2_charge_CCCV = 0;
resultStruct(nTotal,1).C2_discharge_CC = 0;
resultStruct(nTotal,1).C2_discharge_CCCV = 0;
resultStruct(nTotal,1).Normalized_Cumulative = 0;

idxRow = 1;  % 구조체 배열에서 채워나갈 row 인덱스
for i = 1:length(cellFields)
    cName = cellFields{i};
    nCycle = length(rawStruct.(cName).Cycle);
    
    for j = 1:nCycle
        resultStruct(idxRow).Cell = cName;  % 예: 'cell_003'
        resultStruct(idxRow).Cycle = rawStruct.(cName).Cycle(j);
        
        resultStruct(idxRow).C40_charge_CC        = rawStruct.(cName).C40_charge_CC(j);
        resultStruct(idxRow).C40_charge_CCCV      = rawStruct.(cName).C40_charge_CCCV(j);
        resultStruct(idxRow).C40_discharge_CC     = rawStruct.(cName).C40_discharge_CC(j);
        resultStruct(idxRow).C40_discharge_CCCV   = rawStruct.(cName).C40_discharge_CCCV(j);
        resultStruct(idxRow).C2_charge_CC         = rawStruct.(cName).C2_charge_CC(j);
        resultStruct(idxRow).C2_charge_CCCV       = rawStruct.(cName).C2_charge_CCCV(j);
        resultStruct(idxRow).C2_discharge_CC      = rawStruct.(cName).C2_discharge_CC(j);
        resultStruct(idxRow).C2_discharge_CCCV    = rawStruct.(cName).C2_discharge_CCCV(j);
        resultStruct(idxRow).Normalized_Cumulative= rawStruct.(cName).Normalized_Cumulative(j);
        
        idxRow = idxRow + 1;
    end
end


%% 5. 결과 저장
save('finalResult.mat', 'rawStruct', 'resultStruct');

% - rawStruct: cell별로 필드가 나뉜 구조체
% - resultStruct: 모든 (cell, cycle)을 한눈에 보는 구조체 배열

disp('완료! 이제 resultStruct를 더블클릭하면, 모든 셀이 세로로 이어붙여진 표를 볼 수 있습니다.');

