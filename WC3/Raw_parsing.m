%% Build_All_Cell_Data.m
clc; clear; close all;

%% (1) 원 데이터가 들어있는 폴더 경로
dataDir = 'G:\공유 드라이브\BSL_WC';

%% (2) 처리할 CSV 파일 목록 얻기
filePattern = fullfile(dataDir, 'Publishing_data_raw_data_cell_*.csv');
fileList = dir(filePattern);

%% (3) 파일별로 루프
for k = 1:numel(fileList)
    % --- 경로 및 파일명 ---
    filename = fullfile(dataDir, fileList(k).name);
    
    % --- 셀 번호 추출 ---
    tok = regexp(fileList(k).name, 'cell_(\d+)', 'tokens');
    if ~isempty(tok)
        cellNumStr = tok{1}{1};  % ex: '059'
    else
        warning('셀 번호를 추출할 수 없어 건너뜁니다: %s', fileList(k).name);
        continue;
    end
    
    fprintf('Processing cell %s (%d of %d)...\n', cellNumStr, k, numel(fileList));
    
    % --- Import Options 설정 ---
    opts = detectImportOptions(filename, 'VariableNamingRule','preserve');
    % 필요 시 변수형(type) 강제 지정
    opts = setvartype(opts, 'Step', 'double');
    opts = setvartype(opts, 'Full Step #', 'string');
    
    % --- 테이블 읽기 ---
    dataTbl = readtable(filename, opts);
    
    % --- Step 값 변화로 세그먼트 인덱스 찾기 ---
    stepVec   = dataTbl.Step;
    idxChange = find(diff(stepVec) ~= 0);
    nSeg      = numel(idxChange) + 1;
    
    % --- 분할된 테이블 저장 (cell 배열) ---
    dataCell = cell(nSeg,1);
    startIdx = 1;
    for i = 1:numel(idxChange)
        endIdx = idxChange(i);
        dataCell{i} = dataTbl(startIdx:endIdx, :);
        startIdx    = endIdx + 1;
    end
    dataCell{end} = dataTbl(startIdx:end, :);
    
    % --- 구조체 템플릿 정의 ---
    dataTemplate = struct( ...
        'time',      [], ...
        'voltage',   [], ...
        'current',   [], ...
        'cyc',       [], ...
        'step',      [], ...
        'state',     [], ...
        'loop3',     [], ...
        'step_time', [] );
    
    % --- 구조체 배열 초기화 ---
    data = repmat(dataTemplate, nSeg, 1);
    
    % --- 각 세그먼트별로 필드 채우기 ---
    for i = 1:nSeg
        tbl = dataCell{i};
        data(i).time      = tbl.("Test (Sec)");
        data(i).voltage   = tbl.Volts;
        data(i).current   = tbl.("Normalized Current (C-rate)");
        
        data(i).cyc       = unique(tbl.("Cyc#"));
        data(i).step      = unique(tbl.Step);
        data(i).state     = unique(tbl.State);
        data(i).loop3     = unique(tbl.Loop3);
        
        data(i).step_time = tbl.("Step (Sec)");
    end
    
    % --- 결과 MAT 파일로 저장 ---
    saveFilename = fullfile(dataDir, sprintf('cell_%s_data.mat', cellNumStr));
    save(saveFilename, 'data');
end

fprintf('모든 셀 데이터 파싱 및 저장 완료!\n');

