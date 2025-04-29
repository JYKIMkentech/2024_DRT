clc; clear; close all;

%% 1) pkl 파일 경로 설정
filename = 'G:\공유 드라이브\BSL_WC\metadata.pkl';

%% 2) Python의 pickle 모듈 로드 및 파일 열기
pickle = py.importlib.import_module('pickle');
fid = py.open(filename, 'rb');

%% 3) DataFrame 로드
data = pickle.load(fid);

%% 4) 파일 닫기
fid.close();

%% 5) DataFrame 컬럼명 확인
% data.columns는 Pandas의 Index 객체이므로 tolist()로 파이썬 리스트로 변환 후,
% MATLAB의 cell()로 변환하여 사용합니다.
colNames = cell(data.columns.tolist());
disp('=== DataFrame의 컬럼 목록 ===');
disp(colNames);

%% 6) DataFrame → Python dict 변환 (orient='index')
% 인덱스(key)는 단일 정수(py.int)라고 가정합니다.
dataDict = data.to_dict(pyargs('orient', 'index'));

%% 7) dict의 key들을 MATLAB cell array로 변환
dictKeys = dataDict.keys();    % Python dict_keys 객체
pyKeyList = py.list(dictKeys);  % Python list
keyCell = cell(pyKeyList);      % MATLAB cell array

%% 8) 결과를 저장할 MATLAB 구조체 초기화
resultStruct = struct();

%% 9) 각 인덱스(key)에 대해 데이터 처리
% 여기서는 key가 py.int(정수)라고 가정하여, MATLAB double로 변환 후, 'idx_#' 형태의 필드명으로 사용합니다.
for i = 1:numel(keyCell)
    keyVal = keyCell{i};         % 예: py.int
    idxNum = double(keyVal);     % MATLAB double로 변환
    
    % 해당 인덱스의 모든 컬럼 데이터를 포함하는 Python dict 추출
    rowData = dataDict{keyVal};
    
    % 결과 구조체에 저장할 필드명 생성 (예: 'idx_1', 'idx_2', …)
    fieldName = sprintf('idx_%d', idxNum);
    
    % 해당 필드가 없으면 초기화
    if ~isfield(resultStruct, fieldName)
        resultStruct.(fieldName) = struct();
    end
    
    % 각 컬럼에 대해 값을 추출하여 구조체에 저장
    for j = 1:length(colNames)
        % colNames{j}는 py.str이므로 MATLAB 문자열로 변환
        colName_py = colNames{j};
        colName = char(colName_py);
        
        % rowData는 Python dict이므로, 파이썬 key (py.str)로 값을 추출
        val = rowData{colName_py};
        
        % 값의 타입에 따라 MATLAB 자료형으로 변환
        if isa(val, 'py.int') || isa(val, 'py.float')
            val_conv = double(val);
        elseif isa(val, 'py.str')
            val_conv = char(val);
        else
            % 간단한 double 변환이 안될 경우 예외 처리
            try
                val_conv = double(val);
            catch
                val_conv = val;
            end
        end
        
        % MATLAB 구조체 필드명은 유효한 식별자여야 하므로, matlab.lang.makeValidName 사용
        validFieldName = matlab.lang.makeValidName(colName);
        resultStruct.(fieldName).(validFieldName) = val_conv;
    end
end

%% 10) 결과 구조체 확인
disp('=== resultStruct 예시 ===');
disp(resultStruct);

