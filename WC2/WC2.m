clc;        % 콘솔 창 초기화
clear;      % 작업공간 변수 초기화
close all;  % 모든 열린 창 닫기

% JSON 파일 불러오기
jsonFileName = 'protocol_mapping_dic.json'; % JSON 파일 이름
jsonStr = fileread(jsonFileName); % 파일을 문자열로 읽기
jsonData = jsondecode(jsonStr);   % JSON 문자열을 MATLAB 구조체로 변환

% 데이터 확인 (전체 구조 출력)
disp(jsonData);

% 특정 필드 접근 예시 (JSON 구조에 따라 변경해야 함)
if isfield(jsonData, 'protocols') % 예제: 'protocols' 필드가 있는 경우
    disp(jsonData.protocols); % 해당 필드 출력
end

% JSON 데이터 테이블 변환 (필요한 경우)
if isstruct(jsonData) && isfield(jsonData, 'data') % 예제: 'data' 필드가 구조체 배열이면
    jsonTable = struct2table(jsonData.data);
    disp(jsonTable); % 테이블 출력
end
