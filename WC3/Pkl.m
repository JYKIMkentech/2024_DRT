clc; clear; close all;

%% 1. Python 모듈 임포트 및 pickle 파일 로드
py.importlib.import_module('pickle');

% 파일 경로 설정 (백슬래시 두 번 혹은 슬래시 사용)
filePath = 'G:/공유 드라이브/BSL_WC/Publishing_data_diagnostic_capacities.pkl';

% 바이너리 읽기 모드('rb')로 파일 오픈 후, pickle로 DataFrame 로드
fid = py.open(filePath, 'rb');
data = py.pickle.load(fid);

disp(data)  % DataFrame 구조 확인 (옵션)

% DataFrame의 컬럼(열) 이름을 동적으로 추출
pyColumns = cell(py.list(data.columns.tolist()));
colNames = cellfun(@char, pyColumns, 'UniformOutput', false);

%% 2. DataFrame → MATLAB 변환
% (A) 인덱스( (cell, cycle) )와 값(모든 열의 데이터)을 MATLAB cell/배열로 변환
pyIndex = cell(py.list(data.index.tolist()));   % 각 요소: Python tuple (예: {'cell_003', 1.0})
pyValues = cell(py.list(data.values.tolist()));   % 각 행의 데이터 (Python list)

nRows = length(pyIndex);
cellNames = cell(nRows,1);
cycleNumbers = zeros(nRows,1);

% (B) (cell, cycle) 분리 추출
for i = 1:nRows
    idxTuple = pyIndex{i};              % 예: {'cell_003', 1.0}
    cellNames{i} = char(idxTuple{1});     % 'cell_003'
    cycleNumbers(i) = double(idxTuple{2});% 1.0
end

% (C) 각 행의 데이터를 double 배열로 변환 (열의 개수는 동적으로 결정)
nCols = length(pyValues{1});
numData = zeros(nRows, nCols);
for i = 1:nRows
    rowData = pyValues{i};              % Python list
    numData(i,:) = cellfun(@double, cell(rowData));
end

%% 3. 각 cell별로 묶어서 저장: rawStruct
% 실제 cell 이름을 그대로 사용하되, MATLAB 구조체 필드로 사용할 수 있도록 유효한 이름으로 변환
uniqueCells = unique(cellNames);  % 실제 고유 cell 이름들
nCells = length(uniqueCells);

rawStruct = struct();
for i = 1:nCells
    % MATLAB 구조체 필드로 사용 가능한 이름 생성
    validName = matlab.lang.makeValidName(uniqueCells{i});
    idx = strcmp(cellNames, uniqueCells{i});
    
    % 원래의 셀 이름은 ActualName 필드에 저장 (나중에 결과에 반영)
    rawStruct.(validName).ActualName = uniqueCells{i};
    rawStruct.(validName).Cycle = cycleNumbers(idx);
    
    % DataFrame의 모든 열에 대해 동적으로 데이터를 저장
    for k = 1:length(colNames)
        colName = colNames{k};
        validColName = matlab.lang.makeValidName(colName);
        rawStruct.(validName).(validColName) = numData(idx, k);
    end
end

%% 4. 모든 cell과 cycle을 한 ‘세로’로 이어붙여 “표”처럼 만들기: resultStruct
% 각 행(row)은 모든 (cell, cycle) 조합, 열(column)은 'Cell', 'Cycle'과 DataFrame의 컬럼 이름

% 먼저 전체 행 수 계산
nTotal = 0;
cellFields = fieldnames(rawStruct);  % 유효한 cell 필드명들
for i = 1:length(cellFields)
    nTotal = nTotal + length(rawStruct.(cellFields{i}).Cycle);
end

% 결과 구조체에 들어갈 필드 목록 결정: 'Cell', 'Cycle' + DataFrame의 컬럼들(유효한 이름)
colFieldNames = cell(size(colNames));
for k = 1:length(colNames)
    colFieldNames{k} = matlab.lang.makeValidName(colNames{k});
end

% 결과 구조체의 기본 구조 생성 (모든 필드가 포함된 빈 구조체)
sEmpty = struct('Cell', '', 'Cycle', 0);
for k = 1:length(colFieldNames)
    sEmpty.(colFieldNames{k}) = 0;
end

% 사전 할당: 모든 요소가 같은 필드 구성을 갖도록 함
resultStruct = repmat(sEmpty, nTotal, 1);

% 각 (cell, cycle) 조합에 대해 구조체 채우기
idxRow = 1;
for i = 1:length(cellFields)
    validName = cellFields{i};                 % MATLAB 구조체 필드명 (유효한 이름)
    actualName = rawStruct.(validName).ActualName; % 실제 cell 이름
    nCycle = length(rawStruct.(validName).Cycle);
    
    for j = 1:nCycle
        resultStruct(idxRow).Cell = actualName;
        resultStruct(idxRow).Cycle = rawStruct.(validName).Cycle(j);
        % DataFrame의 모든 열을 동적으로 추가
        for k = 1:length(colNames)
            validColName = matlab.lang.makeValidName(colNames{k});
            resultStruct(idxRow).(validColName) = rawStruct.(validName).(validColName)(j);
        end
        idxRow = idxRow + 1;
    end
end

%% 5. 결과 저장
save('finalResult.mat', 'rawStruct', 'resultStruct');

disp('완료! 이제 resultStruct를 더블클릭하면, 모든 셀이 세로로 이어붙여진 표를 볼 수 있습니다.');


