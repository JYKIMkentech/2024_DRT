clc; clear; close all;

% -- 1) pkl 파일 경로
filename = 'G:/공유 드라이브/BSL_WC/diagnostic_features_all.pkl';

% -- 2) 파이썬 pickle 모듈 로드
pickle = py.importlib.import_module('pickle');

% -- 3) 파일 열기 (읽기 모드: 'rb')
fid = py.open(filename, 'rb');

% -- 4) DataFrame 로드
data = pickle.load(fid);

% -- 5) 파일 닫기
fid.close();

%--------------------------------------------------------------------------
% (A) DataFrame 컬럼명 확인
%     Pandas의 Index 타입은 tolist() 로 변환 후, MATLAB cell(...) 적용
%--------------------------------------------------------------------------
colNames = cell(data.columns.tolist());
disp('=== DataFrame의 컬럼 목록 ===');
disp(colNames);

%--------------------------------------------------------------------------
% (B) DataFrame → Python dict 변환 (orient='index')
%     index가 (cellID, cycle)의 튜플이므로 key로 사용됨
%--------------------------------------------------------------------------
dataDict = data.to_dict(pyargs('orient','index'));

% dict의 keys()를 python list로 변환 후, MATLAB cell array로 변환
dictKeys = dataDict.keys;
pyKeyList = py.list(dictKeys);
keyCell   = cell(pyKeyList);

%--------------------------------------------------------------------------
% (C) 결과 구조체 선언
%--------------------------------------------------------------------------
resultStruct = struct();

%--------------------------------------------------------------------------
% (D) key(=인덱스 튜플)별로 순회하면서 구조체에 저장
%--------------------------------------------------------------------------
for i = 1:numel(keyCell)
    % keyCell{i}는 파이썬 튜플 → 다시 MATLAB cell로 변환
    pyTuple = keyCell{i};               % 예: ('cell_003', 28.0)
    tupleInMatlab = cell(pyTuple);      
    
    % 첫 번째 원소: cellID (문자열), 두 번째 원소: cycle (숫자)
    cellID  = char(tupleInMatlab{1});   % 예: 'cell_003'
    cycleNo = double(tupleInMatlab{2}); % 예: 28.0
    
    % 해당 key에 대한 rowData (Python dict) 가져오기
    rowData = dataDict{pyTuple};
    
    % 원하는 컬럼 뽑아서 double 변환
    capacityNormalized = double(rowData{'C/2 discharge CC Capacity [normalized]'});
    efcsValue          = double(rowData{'EFCs'});
    
    % 현재 cellID 필드가 없다면 초기화
    if ~isfield(resultStruct, cellID)
        resultStruct.(cellID) = struct( ...
            'Cycle',              [], ...
            'CapacityNormalized', [], ...
            'EFCs',               []);
    end
    
    % 필드에 데이터 추가
    resultStruct.(cellID).Cycle(end+1)              = cycleNo;
    resultStruct.(cellID).CapacityNormalized(end+1) = capacityNormalized;
    resultStruct.(cellID).EFCs(end+1)               = efcsValue;
end

%--------------------------------------------------------------------------
% (E) 결과 예시 확인
%--------------------------------------------------------------------------
disp('=== 결과 구조체 예시 (cell_003) ===');
disp(resultStruct.cell_003);  
