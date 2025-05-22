%% analyzeTrips_SOC.m
% -------------------------------------------------------------------------
%  선택한 Folder의 ParseResults에서 Driving SoC 계산 후
%  V,I,t,soc 4개 열을 갖는 nx4 double 형식으로 Results 생성
%  • 초기 SoC: OCVtable에서 OCV→SoC 역보간 (중복 전압 제거 후 linear)
%  • Coulomb-counting으로 SoC 시간 프로파일 계산
%  • 셀 구성: pouch cell (4p3s) × 36 modules → 총 432 cells
%  • pouch cell 용량: 64 Ah → 개별 cell SoC 계산
%  • 결과: Results.mat으로 저장 (각 Trip은 nx4 double)
% -------------------------------------------------------------------------

clc; clear; close all;

%% 1) 사용자 입력: Folder 번호 ---------------------------------------------
validFolders = [2 4 6 8 10 12 14 16];
while true
    folderNum = input('분석할 Folder 번호를 입력하세요 (2,4,6,8,10,12,14,16): ');
    if ismember(folderNum, validFolders), break; end
    fprintf('⚠️  %d 은(는) 허용되지 않는 번호입니다. 다시 입력하세요.\n', folderNum);
end

%% 2) ParseResults 로드 ---------------------------------------------------
basePath   = 'G:\공유 드라이브\BSL_Audi\Drive';
folderPath = fullfile(basePath, sprintf('Folder%d', folderNum));
prFile     = fullfile(folderPath, sprintf('ParseResults%d.mat', folderNum));
if ~exist(prFile,'file')
    error('ParseResults 파일을 찾을 수 없습니다:\n%s', prFile);
end
S = load(prFile, 'ParseResults');
ParseResults = S.ParseResults;
tripFields   = fieldnames(ParseResults);
tripFields(strcmp(tripFields,'DrivingNum')) = [];

%% 3) OCV-SOC 테이블 로드 및 중복 제거 -------------------------------------
ocvDir    = 'G:\공유 드라이브\BSL_Audi\OCV';
ocvFile   = fullfile(ocvDir, 'OCVtable.mat');
if ~exist(ocvFile,'file')
    error('OCVtable 파일을 찾을 수 없습니다:\n%s', ocvFile);
end
T = load(ocvFile);
if isfield(T,'OCVtable')
    raw = T.OCVtable;
elseif isfield(T,'OCVtbl')
    raw = T.OCVtbl;
else
    error('OCVtable 변수(OCVtable 또는 OCVtbl)가 MAT 파일에 없습니다.');
end
[Vuniq, ia] = unique(raw(:,2),'stable');
SoCuniq     = raw(ia,1);

%% 4) 셀 및 pack 구성 정보 ------------------------------------------------
cellCapacityAh = 64;       % pouch cell 용량 [Ah]
cellParallel   = 4;        % 병렬 셀 수
seriesModules  = 36;       % 직렬 모듈 수
cellsPerMod    = 3;        % 모듈당 직렬 셀 수
cellSeries     = seriesModules * cellsPerMod;  % 총 직렬 셀 수
Q_cell_total   = cellCapacityAh * 3600;        % cell 총 전하량 [C]

%% 5) Results 구조체 생성 (nx4 double) ------------------------------------
Results = struct('Folder', folderNum);
for i=1:numel(tripFields)
    fn   = tripFields{i};
    dat  = ParseResults.(fn);        % [V_pack, I_pack, t]
    Vp   = dat(:,1);
    Ip   = dat(:,2);
    tp   = dat(:,3);

    % cell 단위 변환
    Vcell = Vp ./ cellSeries;
    Icell = Ip ./ cellParallel;
    % 초기 SoC 보간
    soc0  = interp1(Vuniq, SoCuniq, Vcell(1), 'linear', 'extrap');
    % coulomb-counting
    Qint  = cumtrapz(tp, Icell);
    soc   = soc0 - Qint / Q_cell_total;
    soc   = max(0, min(1, soc));

    % nx4 double: [V_pack, I_pack, time, soc]
    Results.(fn) = [Vp, Ip, tp, soc];
end

%% 6) Results 저장 -------------------------------------------------------
outFile = fullfile(folderPath, 'Results.mat');
save(outFile, 'Results');
fprintf('✔️ Results.mat 저장 완료: %s\n', outFile);
